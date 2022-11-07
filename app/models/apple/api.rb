# frozen_string_literal: true

require "uri"
require "net/http"
require "base64"

module Apple
  class Api
    ERROR_RETRIES = 3
    SUCCESS_CODES = %w(200 201).freeze

    attr_accessor :provider_id, :key_id, :key

    def self.from_env
      apple_key_pem = Base64.decode64(ENV["APPLE_KEY_PEM_B64"])

      new(provider_id: ENV["APPLE_PROVIDER_ID"],
          key_id: ENV["APPLE_KEY_ID"],
          key: apple_key_pem)
    end

    def initialize(**attributes)
      attributes = attributes.with_indifferent_access
      @provider_id = attributes[:provider_id]
      @key_id = attributes[:key_id]
      @key = attributes[:key]
    end

    def ec_key
      @ec_key ||= OpenSSL::PKey::EC.new(key)
    end

    def jwt_payload
      now = Time.now.utc

      { iss: provider_id,
        exp: now.to_i + (60 * 15),
        aud: "podcastsconnect-v1" }
    end

    def jwt_headers
      { kid: key_id }
    end

    def jwt
      JWT.encode(jwt_payload, ec_key, "ES256", jwt_headers)
    end

    def api_base
      "https://api.podcastsconnect.apple.com/v1/"
    end

    def list_shows
      get("shows")
    end

    def set_headers(req)
      req["Authorization"] = "Bearer #{jwt}"
      req["Content-Type"] = "application/json"

      req
    end

    def get_paged_collection(api_frag)
      uri = join_url(api_frag)

      res = []
      loop do
        break if uri.nil?

        resp = get_uri(uri)
        json = unwrap_response(resp)
        res << json["data"]

        next_uri = json["links"]["next"]

        uri =
          if next_uri
            URI.join(next_uri)
          end
      end

      res.flatten
    end

    def join_url(api_frag)
      URI.join(api_base, api_frag)
    end

    def local_api_retry_errors
      count = 0
      last_resp = nil
      while count < ERROR_RETRIES
        count += 1
        last_resp = yield
        break if ok_code(last_resp)
      end

      last_resp
    end

    def get(api_frag)
      uri = join_url(api_frag)
      local_api_retry_errors do
        get_uri(uri)
      end
    end

    def patch(api_frag, data_body)
      local_api_retry_errors do
        update_remote(Net::HTTP::Patch, api_frag, data_body)
      end
    end

    def post(api_frag, data_body)
      local_api_retry_errors do
        update_remote(Net::HTTP::Post, api_frag, data_body)
      end
    end

    def countries_and_regions
      json = unwrap_response(get("countriesAndRegions?limit=200"))
      json["data"].map { |h| h.slice("type", "id") }
    end

    def check_row(row_operation)
      return true unless row_operation.instance_of?(Hash)

      if row_operation.key?("api_response") && row_operation.dig("api_response", "err")
        raise row_operation.dig("api_response", "val").to_json
      end

      true
    end

    def ok_code(resp)
      SUCCESS_CODES.include?(resp.code)
    end

    def unwrap_response(resp)
      raise Apple::ApiError.new("Apple returning #{resp.code}"), resp.body unless ok_code(resp)

      JSON.parse(resp.body)
    end

    def unwrap_bridge_response(resp)
      raise Apple::ApiError.new("Bridge returning #{resp.code}"), resp.body unless ok_code(resp)

      parsed = JSON.parse(resp.body)

      raise "Expected an array response" unless parsed.instance_of?(Array)

      (oks, errs) = %w(ok err).map do |key|
        parsed.select { |row_operation| row_operation["api_response"][key] == true }
      end

      (fixed_errs, remaining_errors) = yield(errs)

      [oks + fixed_errs, remaining_errors]
    end

    def bridge_remote(bridge_resource, bridge_options)
      # TODO: pull this in via the ENV
      uri = URI.join("http://127.0.0.1:3000", "/bridge")

      Rails.logger.info("Apple::Api BRIDGE #{bridge_resource} #{uri.hostname}:#{uri.port}/bridge")

      body = {
        bridge_resource: bridge_resource,
        bridge_parameters: bridge_options
      }

      make_bridge_request(uri, body)
    end

    def bridge_remote_and_unwrap(bridge_resource, bridge_options, &block)
      resp = bridge_remote(bridge_resource, bridge_options)

      unwrap_bridge_response(resp, &block)
    end

    def bridge_remote_and_retry(bridge_resource, bridge_options)
      resp = bridge_remote(bridge_resource, bridge_options)

      unwrap_bridge_response(resp) do |row_operation_errors|
        retry_bridge_api_operation(bridge_resource, [], row_operation_errors)
      end
    end

    def bridge_remote_and_retry!(bridge_resource, bridge_options)
      (oks, errs) = bridge_remote_and_retry(bridge_resource, bridge_options)
      raise Apple::ApiError.new(errs.to_json) if errs.present?

      oks
    end

    private

    def make_bridge_request(uri, body)
      req = Net::HTTP::Post.new(uri)
      req.body = body.to_json
      req = set_headers(req)

      # TODO: vary this with the bridge endpoint url
      use_ssl = false

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        http.request(req)
      end
    end

    # Takes in a bridge resource and a list of oks (successful requests) and
    # errs (failed requests).  Retries errs and adds any former_errors_now_ok to
    # the oks and recurses on the remaining errs.
    def retry_bridge_api_operation(bridge_resource, row_operations_ok, row_operation_errs, attempts = 1)
      return [row_operations_ok, row_operation_errs] if attempts >= ERROR_RETRIES || row_operation_errs.empty?

      Rails.logger.error("Retrying!")

      # Slice off the api response and retry the row operation
      formatted_error_operations_for_retry = row_operation_errs.map do |r|
        r.slice("request_metadata", "api_parameters", "api_url")
      end

      # Working *only* on the row_operation_errs here in the call to `bridge_remote``
      # So `former_errors_now_ok`, and `repeated_errs` here are derivative solely of `row_operation_errs`
      (former_errors_now_ok, repeated_errs) =
        bridge_remote_and_unwrap(bridge_resource,
                                 formatted_error_operations_for_retry) do |additional_row_operation_errs|
        if additional_row_operation_errs.empty?
          [[],
           []]
        else
          # Keep working on the errors if there are any
          retry_bridge_api_operation(bridge_resource, [],
                                     additional_row_operation_errs, attempts + 1)
        end
      end

      [row_operations_ok + former_errors_now_ok, repeated_errs]
    end

    def get_uri(uri)
      Rails.logger.info("Apple::Api GET #{uri}")

      req = Net::HTTP::Get.new(uri)
      req = set_headers(req)

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
    end

    def update_remote(method_class, api_frag, data_body)
      method_label = method_class.name.demodulize.upcase
      Rails.logger.info("Apple::Api #{method_label} #{join_url(api_frag)}")

      uri = join_url(api_frag)

      req = method_class.new(uri)
      req = set_headers(req)

      req.body = data_body.to_json

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
    end
  end
end
