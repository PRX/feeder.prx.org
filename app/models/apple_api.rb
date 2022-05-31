# frozen_string_literal: true

class AppleApi

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
    { kid: key_id,
      iss: provider_id,
      exp: Time.now.to_i + (60 * 15) }
  end

  def jwt
    JWT.encode(jwt_payload, ec_key, 'ES256')
  end
end
