# frozen_string_literal: true

require "test_helper"
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

  describe "#bridge_remote" do
    it "stubs an empty response if there are no params given" do
      resp = api.bridge_remote("someResource", [])
      assert_equal "[]", resp.body
      assert_equal OpenStruct, resp.class
    end
  end

  describe "#bridge_remote_and_retry" do
    it "exhausts retries until failure" do
      bridge_failure_response = [
        build(:bridge_row_error)
      ]

      api.stub(:make_bridge_request, OpenStruct.new(body: bridge_failure_response.to_json, code: "200")) do
        ok, err = api.bridge_remote_and_retry("someResource", [{foo: "bar"}])

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
        ok, err = api.bridge_remote_and_retry("someResource", [{foo: "bar"}])

        assert_equal ok.as_json, bridge_success_response.as_json
        assert_equal err, []
        assert_equal return_count, 2
      end
    end
  end

  describe ".from_apple_config" do
    it "creates an api from apple credentials" do
      creds = build(:apple_config)
      api = Apple::Api.from_apple_config(creds)

      assert_equal api.provider_id, creds.provider_id
      assert_equal api.key_id, creds.key_id
      assert_equal api.key, creds.key_pem
    end

    it "falls back on the environment if the apple credential attributes are not set" do
      creds = create(:apple_config, key: nil)
      api = Apple::Api.from_apple_config(creds)
      assert_equal api.key_id, "apple key id from env"

      assert_equal api.key_id, ENV["APPLE_KEY_ID"]
      assert_equal api.key, Base64.decode64(ENV["APPLE_KEY_PEM_B64"])
      assert_equal api.provider_id, ENV["APPLE_PROVIDER_ID"]
    end
  end

  describe "#localhost_bridge_url" do
    it "returns true when the env is configured with a localhost bridge url" do
      api = Apple::Api.new(provider_id: "asdf", key_id: "asdf", key: "asdf", bridge_url: "http://localhost:3000")
      assert api.localhost_bridge_url?

      api = Apple::Api.new(provider_id: "asdf", key_id: "asdf", key: "asdf", bridge_url: "http://amazon-aws.biz:3000")
      refute api.localhost_bridge_url?
    end
  end

  describe "#set_headers" do
    it "sets a User-Agent header" do
      headers = api.set_headers({})
      assert_equal headers["User-Agent"], "PRX-Feeder-Apple/1.0 (Rails-test)"
    end
  end

  describe "#response" do
    it "has the result type structure wrapped in an api_response key" do
      http_response = OpenStruct.new(code: "999", body: {a: :b}.to_json)
      assert_equal api.response(http_response).keys, ["api_response"]
      assert_equal api.response(http_response)["api_response"].keys.sort, ["err", "ok", "val"].sort
    end

    it "returns an ok with something like a 200" do
      http_response = OpenStruct.new(code: "210", body: {awesome: :api}.to_json)
      api_response = api.response(http_response)
      assert_equal false, api_response["api_response"]["err"]
      assert_equal true, api_response["api_response"]["ok"]

      assert_equal({"awesome" => "api"}, api_response["api_response"]["val"])
    end

    it "returns an error with something other than a 200" do
      http_response = OpenStruct.new(code: "404", body: {not: :found}.to_json)
      api_response = api.response(http_response)
      assert_equal true, api_response["api_response"]["err"]
      assert_equal false, api_response["api_response"]["ok"]

      assert_equal({"not" => "found"}, api_response["api_response"]["val"])
    end

    it "calls the log error method when there is an error" do
      http_response = OpenStruct.new(code: "404", body: {not: :found}.to_json)

      mock = Minitest::Mock.new
      mock.expect(:call, nil, [{"api_response" => {"ok" => false, "err" => true, "val" => {"not" => "found"}}}])
      api.stub(:log_response_error, mock) { api.response(http_response) }

      assert mock.verify
    end

    it "does not call the log error method when there is no error" do
      http_response = OpenStruct.new(code: "299", body: {so: :good}.to_json)

      api.stub(:log_response_error, ->(**) { raise "should not be called" }) do
        res = api.response(http_response)
        assert res[:api_response][:ok]
      end
    end
  end

  describe "#unwrap_bridge_response" do
    let(:ok_row) { {api_response: {ok: true, err: false, val: {data: {status: 200}}}}.with_indifferent_access }
    let(:not_found_row) { {api_response: {ok: false, err: true, val: {data: {status: 404}}}}.with_indifferent_access }

    it "handles strings or integers" do
      assert_equal [[], []], api.unwrap_bridge_response(OpenStruct.new(code: "200", body: [].to_json))
      assert_equal [[], []], api.unwrap_bridge_response(OpenStruct.new(code: 200, body: [].to_json))
    end

    it "groups 'ok' data into the ok response array" do
      assert_equal [[ok_row], []], api.unwrap_bridge_response(OpenStruct.new(code: "201", body: [ok_row].to_json))
    end

    it "groups 'err' data into the err response array" do
      assert_equal [[], [not_found_row]], api.unwrap_bridge_response(OpenStruct.new(code: "201", body: [not_found_row].to_json))
    end

    it "raises for a 4xx and 5xx _bridge_ reponse" do
      # it raises Apple::ApiError
      assert_raises Apple::ApiError do
        api.unwrap_bridge_response(OpenStruct.new(code: "404", body: [].to_json))
      end
      assert_raises Apple::ApiError do
        api.unwrap_bridge_response(OpenStruct.new(code: "500", body: [].to_json))
      end
    end

    it "can optionally treat a 404 as ok, excising the missing responses" do
      assert_equal [[ok_row], []], api.unwrap_bridge_response(OpenStruct.new(code: "200", body: [not_found_row, ok_row].to_json), ignore_errors: [::Apple::Api::NOT_FOUND])
    end
  end
end
