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
  let(:api) { apple_api }

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

  describe "#bridge_remote_and_retry" do
    it "exhausts retries until failure" do
      bridge_failure_response = [
        build(:bridge_row_error)
      ]

      api.stub(:make_bridge_request, OpenStruct.new(body: bridge_failure_response.to_json, code: "200")) do
        ok, err = api.bridge_remote_and_retry("someResource", [])

        assert_equal ok, []
        assert_equal err.as_json, bridge_failure_response.as_json
      end
    end

    it "returns corrected errors as ok" do
      bridge_failure_response = [
        build(:bridge_row_error)
      ]

      bridge_success_response = [
        build(:bridge_row)
      ]

      return_count = 0
      return_values = [bridge_failure_response, bridge_success_response]

      returner = proc do
        return_count += 1
        v = return_values.shift
        OpenStruct.new(body: v.to_json, code: "200")
      end

      api.stub(:make_bridge_request, returner) do
        ok, err = api.bridge_remote_and_retry("someResource", [])

        assert_equal ok.as_json, bridge_success_response.as_json
        assert_equal err, []
        assert_equal return_count, 2
      end
    end
  end
end
