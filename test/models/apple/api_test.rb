# frozen_string_literal: true

require "test_helper"
require "prx_access"
require "base64"
require "securerandom"

describe Apple::Api do
  let(:ecdsa_pem) do
    test_file("/fixtures/apple_podcasts_connect_keyfile.pem")
  end

  let(:provider_id) { SecureRandom.uuid }

  let(:key_id) { "asdfasdf" }

  let(:apple_api) { build(:apple_api, provider_id: provider_id, key_id: key_id, key: ecdsa_pem) }
  let(:api) { apple_api }

  it "assigns the base64 key" do
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

  describe "#local_api_retry_errors" do
    it "local api attempts exhausts retries until failure" do
      attempts = 0

      res = api.local_api_retry_errors do
        attempts += 1
        OpenStruct.new(code: "543")
      end

      assert_equal 3, attempts
      assert_equal "543", res.code
    end

    it "succeeds after some failures" do
      responses = [
        OpenStruct.new(code: "543"),
        OpenStruct.new(code: "543"),
        OpenStruct.new(code: "200")
      ]

      attempts = 0
      res = api.local_api_retry_errors do
        attempts += 1
        responses.shift
      end

      assert_equal 3, attempts
      assert_equal "200", res.code
    end
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

  describe ".from_apple_credentials" do
    it "creates an api from apple credentials" do
      creds = build(:apple_api_credentials)
      api = Apple::Api.from_apple_credentials(creds)

      assert_equal api.provider_id, creds.provider_id
      assert_equal api.key_id, creds.key_id
      assert_equal api.key, creds.key
    end
  end
end
