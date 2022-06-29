# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'base64'

class Apple::Api

  attr_reader :provider_id, :key_id, :key

  SUCCESS_CODES = ['200', '201'].freeze

  def self.from_env
    apple_key_pem = Base64.decode64(ENV['APPLE_KEY_PEM_B64'])

    new(ENV['APPLE_PROVIDER_ID'],
        ENV['APPLE_KEY_ID'],
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
      aud: 'podcastsconnect-v1',
    }
  end

  def jwt_headers
    { kid: key_id }
  end

  def jwt
    JWT.encode(jwt_payload, ec_key, 'ES256', jwt_headers)
  end

  def api_base
    'https://api.podcastsconnect.apple.com/v1/'
  end

  def list_shows
    get('shows')
  end

  def set_headers(req)
    req['Authorization'] = "Bearer #{jwt}"
    req['Content-Type'] = 'application/json'

    req
  end

  def get(api_frag)
    uri = join_url(api_frag)

    req = Net::HTTP::Get.new(uri)
    req = set_headers(req)

    resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    resp
  end

  def patch(api_frag, data_body)
    update_remote(Net::HTTP::Patch, api_frag, data_body)
  end

  def post(api_frag, data_body)
    update_remote(Net::HTTP::Post, api_frag, data_body)
  end

  def countries_and_regions
    json = unwrap_response(get('countriesAndRegions?limit=200'))
    json['data'].map { |h| h.slice('type', 'id')}
  end

  def unwrap_response(resp)
    raise Apple::ApiError, resp.body unless SUCCESS_CODES.include?(resp.code)

    JSON.parse(resp.body)
  end

  private

  def update_remote(method_class, api_frag, data_body)
    uri = join_url(api_frag)

    req = method_class.new(uri)
    req = set_headers(req)

    req.body = data_body.to_json

    resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    resp
  end

  def join_url(api_frag)
    URI.join(api_base, api_frag)
  end
end
