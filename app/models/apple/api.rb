# frozen_string_literal: true

require "uri"
require "net/http"
require "base64"

module Apple
  class Api
    attr_reader :provider_id, :key_id, :key

    SUCCESS_CODES = %w(200 201).freeze

    def self.from_env
      apple_key_pem = Base64.decode64(ENV["APPLE_KEY_PEM_B64"])

      new(ENV["APPLE_PROVIDER_ID"],
          ENV["APPLE_KEY_ID"],
          apple_key_pem)
    end

    def initialize(provider_id, key_id, key)
      @provider_id = provider_id
      @key_id = key_id
      @key = key
    end

    def ec_key
      @ec_key ||= OpenSSL::PKey::EC.new(key)
    end

    def jwt_payload
      now = Time.now.utc

      { iss: provider_id,
        exp: now.to_i + (60 * 15),
        aud: "podcastsconnect-v1", }
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

    def get(api_frag)
      uri = join_url(api_frag)

      get_uri(uri)
    end

    def patch(api_frag, data_body)
      update_remote(Net::HTTP::Patch, api_frag, data_body)
    end

    def post(api_frag, data_body)
      update_remote(Net::HTTP::Post, api_frag, data_body)
    end

    def countries_and_regions
      json = unwrap_response(get("countriesAndRegions?limit=200"))
      json["data"].map { |h| h.slice("type", "id") }
    end

    def unwrap_response(resp)
      raise Apple::ApiError, resp.body unless SUCCESS_CODES.include?(resp.code)

      JSON.parse(resp.body)
    end

    def bridge_remote(bridge_label, bridge_options)
      # TODO
      uri = URI.join("http://127.0.0.1:3000", "/bridge")

      Rails.logger.info("Apple::Api BRIDGE #{bridge_label} #{uri.hostname}:#{uri.port}/bridge")

      body = {
        name: bridge_label,
        options: bridge_options
      }

      req = Net::HTTP::Post.new(uri)
      req.body = body.to_json
      req = set_headers(req)

      # TODO
      use_ssl = false

      Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        http.request(req)
      end
    end

    private

    def get_uri(uri)
      Rails.logger.info("Apple::Api GET #{uri}")

      req = Net::HTTP::Get.new(uri)
      req = set_headers(req)

      resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end

      resp
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
