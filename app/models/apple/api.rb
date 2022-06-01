# frozen_string_literal: true

require 'uri'
require 'net/http'

class Apple::Api

  attr_reader :provider_id, :key_id, :key

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

  def list_shows
    get('shows')
  end

  def api_base
    'https://api.podcastsconnect.apple.com/v1/'
  end

  private

  def join_url(api_frag)
    URI.join(api_base, api_frag)
  end

  def get(api_frag)
    uri = join_url(api_frag)

    req = Net::HTTP::Get.new(uri)
    req['Authorization'] = "Bearer #{jwt}"

    resp = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end
  end
end
