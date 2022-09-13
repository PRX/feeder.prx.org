# frozen_string_literal: true

require "test_helper"
require "prx_access"
require "base64"
require "securerandom"

describe Apple::Api do
  let(:ecdsa_pem) do
    "-----BEGIN EC PRIVATE KEY-----\nMHcCAQEEIHGYE/QPYUkdUAfs72gQTBA9i5A6DgvIE8iiWtkC1Rp7oAoGCCqGSM49\nAwEHoUQDQgAEhqIHUYP3wBlLvs/AZK3VGum/j/+2HgUQzt78LT4nS+rI1JVIOFrU\nRUFz6kRgJExlrf7oHfqfLYjvF3BoOzfmlw==\n-----END EC PRIVATE KEY-----\n"
  end

  let(:provider_id) { SecureRandom.uuid }

  let(:key_id) { "asdfasdf" }

  let(:apple_api) { Apple::Api.new(provider_id, key_id, ecdsa_pem) }

  it "decodes the base64 key" do
    assert_equal(apple_api.key, ecdsa_pem)
  end

  it "constructs a jwt" do
    jwt = apple_api.jwt
    decoded = JWT.decode(apple_api.jwt, nil, false)
    payload = decoded.first

    assert_equal payload["iss"], provider_id
    assert Time.at(payload["exp"]).utc.to_datetime > Time.now.utc + 14.minutes

    algo = decoded.second

    assert_equal algo, "typ" => "JWT", "alg" => "ES256", "kid" => key_id
  end
end
