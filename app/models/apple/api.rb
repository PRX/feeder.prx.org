# frozen_string_literal: true

module Apple
  class Api
    API_BASE = "https://api.podcastsconnect.apple.com/v1/"

    ERROR_RETRIES = 3
    SUCCESS_CODES = [200, 201].freeze
    DEFAULT_BATCH_SIZE = 5
    DEFAULT_WRITE_BATCH_SIZE = 1

    NOT_FOUND = 404
    CONFLICT = 409

    attr_accessor :provider_id, :key_id, :key, :bridge_url

    def self.from_env
      apple_key_id = ENV["APPLE_KEY_ID"]
      apple_provider_id = ENV["APPLE_PROVIDER_ID"]
      apple_key_pem_b64 = ENV["APPLE_KEY_PEM_B64"]

      raise "Apple::Api.from_env Apple key details missing from ENV" if [apple_key_id, apple_provider_id, apple_key_pem_b64].any?(&:blank?)

      apple_key_pem = Base64.decode64(apple_key_pem_b64)

      new(provider_id: apple_provider_id,
        key_id: apple_key_id,
        key: apple_key_pem)
    end

    def self.from_key(apple_key)
      new(provider_id: apple_key.provider_id,
        key_id: apple_key.key_id,
        key: apple_key.key_pem)
    end

    def self.from_apple_config(apple_config)
      if apple_config.key.blank?
        Rails.logger.info("No Apple API keys in config object, falling back to environment default keys",
          {apple_config_id: apple_config.id,
           podcast_id: apple_config.podcast_id,
           podcast_title: apple_config.podcast_title})
        from_env
      else
        new(provider_id: apple_config.key.provider_id,
          key_id: apple_config.key.key_id,
          key: apple_config.key.key_pem)
      end
    end

    def initialize(provider_id:, key_id:, key:, bridge_url: nil)
      bridge_url = ENV.fetch("APPLE_API_BRIDGE_URL") unless bridge_url.present?

      @provider_id = provider_id
      @key_id = key_id
      @key = key
      @bridge_url = URI(bridge_url)
    end

    def inspect
      "#<Apple:Api:#{object_id} key_id=#{@key_id || "nil"} bridge_url=#{@bridge_url || "nil"}>"
    end

    def ec_key
      @ec_key ||= OpenSSL::PKey::EC.new(key)
    end

    def jwt_payload
      now = Time.now.utc

      {iss: provider_id,
       exp: now.to_i + (60 * 15),
       aud: "podcastsconnect-v1"}
    end

    def jwt_headers
      {kid: key_id, typ: "JWT"}
    end

    def jwt
      JWT.encode(jwt_payload, ec_key, "ES256", jwt_headers)
    end

    def list_shows
      get("shows")
    end

    def set_headers(req)
      req["Authorization"] = "Bearer #{jwt}"
      req["Content-Type"] = "application/json"
      req["User-Agent"] = "PRX-Feeder-Apple/1.0 (Rails-#{Rails.env})"

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
          (URI.join(next_uri) if next_uri)
      end

      res.flatten
    end

    def self.join_url(api_frag)
      URI.join(API_BASE, api_frag)
    end

    def join_url(api_frag)
      self.class.join_url(api_frag)
    end

    def local_api_retry_errors(tries: ERROR_RETRIES)
      count = 0
      last_resp = nil
      while count < tries
        count += 1
        last_resp = yield
        break if ok_code(last_resp)
      end

      last_resp
    end

    def get(api_frag, tries: ERROR_RETRIES)
      uri = join_url(api_frag)
      local_api_retry_errors(tries: tries) do
        get_uri(uri)
      end
    end

    def patch(api_frag, data_body, tries: ERROR_RETRIES)
      uri = join_url(api_frag)
      local_api_retry_errors(tries: tries) do
        update_remote(Net::HTTP::Patch, uri, data_body)
      end
    end

    def post(api_frag, data_body, tries: ERROR_RETRIES)
      uri = join_url(api_frag)
      local_api_retry_errors(tries: tries) do
        update_remote(Net::HTTP::Post, uri, data_body)
      end
    end

    def delete(api_frag, tries: ERROR_RETRIES)
      uri = join_url(api_frag)
      local_api_retry_errors(tries: tries) do
        update_remote(Net::HTTP::Delete, uri, {})
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

    def ok_code(resp, ignore_errors: [])
      if ignore_errors.map(&:to_i).include?(resp.code.to_i)
        Rails.logger.info("Apple::Api#ok_code ignoring error", {code: resp.code.to_i})
        return true
      end

      SUCCESS_CODES.include?(resp.code.to_i)
    end

    def log_response_error(resp)
      Rails.logger.info "Apple::Show#log_sync_error", {
        body: resp["api_response"]["val"]
      }
    end

    def response(resp)
      ok = resp.code.to_i < 300
      json =
        begin
          JSON.parse(resp.body)
        rescue JSON::ParserError
          resp.body
        end

      resp =
        {
          api_response: {
            ok: ok,
            err: !ok,
            val: json
          }
        }.with_indifferent_access

      log_response_error(resp) unless ok

      resp
    end

    def unwrap_response(resp, ignore_errors: [])
      raise Apple::ApiError.new("Apple Api Error", resp) unless ok_code(resp, ignore_errors: ignore_errors)

      JSON.parse(resp.body)
    end

    def unwrap_bridge_response(resp, ignore_errors: [])
      raise Apple::ApiError.new("Apple Api Bridge Error", resp) unless ok_code(resp, ignore_errors: ignore_errors)

      parsed = JSON.parse(resp.body)

      raise "Expected an array response" unless parsed.instance_of?(Array)

      (oks, errs) = %w[ok err].map do |key|
        parsed.select { |row_operation| row_operation["api_response"][key] == true }
      end

      # ignore errors if requested
      errs = errs.reject { |err| ignore_errors.map(&:to_i).include?(err.dig("api_response", "val", "data", "status").to_i) }

      (fixed_errs, remaining_errors) =
        if block_given?
          yield(errs)
        else
          [[], errs]
        end

      [oks + fixed_errs, remaining_errors]
    end

    def bridge_remote(bridge_resource, bridge_options, batch_size: DEFAULT_BATCH_SIZE)
      url = bridge_url
      Rails.logger.info("Apple::Api BRIDGE #{bridge_resource} #{url.hostname}:#{url.port}/bridge", {param_count: bridge_options.count})

      body = {
        batch_size: batch_size,
        bridge_resource: bridge_resource,
        bridge_parameters: bridge_options
      }

      return OpenStruct.new(code: "200", body: "[]") if bridge_options.empty?

      make_bridge_request(body, url)
    end

    def bridge_remote_and_unwrap(bridge_resource, bridge_options, batch_size: DEFAULT_BATCH_SIZE, &block)
      resp = bridge_remote(bridge_resource, bridge_options, batch_size: batch_size)

      unwrap_bridge_response(resp, &block)
    end

    def bridge_remote_and_retry(bridge_resource, bridge_options, batch_size: DEFAULT_BATCH_SIZE, ignore_errors: [])
      resp = bridge_remote(bridge_resource, bridge_options, batch_size: batch_size)

      unwrap_bridge_response(resp, ignore_errors: ignore_errors) do |row_operation_errors|
        retry_bridge_api_operation(bridge_resource, [], row_operation_errors)
      end
    end

    def bridge_remote_and_retry!(bridge_resource, bridge_options, **args)
      (oks, errs) = bridge_remote_and_retry(bridge_resource, bridge_options, **args)
      raise_bridge_api_error(errs) if errs.present?

      oks
    end

    def raise_bridge_api_error(err)
      raise Apple::ApiError.new(JSON.pretty_generate(err), nil)
    end

    def development_bridge_url?
      localhost_bridge_url?
    end

    def localhost_bridge_url?
      bridge_url.hostname == "localhost"
    end

    private

    def make_bridge_request(body, uri)
      req = Net::HTTP::Post.new(uri)
      req.body = body.to_json
      req = set_headers(req)

      # test if the apple_bridge_url is https
      use_ssl = bridge_url.scheme == "https"

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl, read_timeout: 10.minutes) do |http|
        http.request(req)
      end
    end

    # Takes in a bridge resource and a list of oks (successful requests) and
    # errs (failed requests).  Retries errs and adds any former_errors_now_ok to
    # the oks and recurses on the remaining errs.
    def retry_bridge_api_operation(bridge_resource, row_operations_ok, row_operation_errs, attempts = 1, batch_size: DEFAULT_BATCH_SIZE)
      return [row_operations_ok, row_operation_errs] if attempts >= ERROR_RETRIES || row_operation_errs.empty?

      row_operation_errs.map { |err| Rails.logger.warn("Retrying: #{err.to_json}") }

      # Slice off the api response and retry the row operation
      formatted_error_operations_for_retry = row_operation_errs.map do |r|
        r.slice("request_metadata", "api_parameters", "api_url")
      end

      # Working *only* on the row_operation_errs here in the call to `bridge_remote``
      # So `former_errors_now_ok`, and `repeated_errs` here are derivative solely of `row_operation_errs`
      (former_errors_now_ok, repeated_errs) =
        bridge_remote_and_unwrap(bridge_resource, formatted_error_operations_for_retry, batch_size: batch_size) do |additional_row_operation_errs|
        if additional_row_operation_errs.empty?
          [[],
            []]
        else
          # Keep working on the errors if there are any
          retry_bridge_api_operation(bridge_resource, [],
            additional_row_operation_errs, attempts + 1, batch_size: batch_size)
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
