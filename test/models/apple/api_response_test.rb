# frozen_string_literal: true

require "test_helper"

class TestResponse
  include Apple::ApiResponse
  attr_accessor :api_response
end

describe Apple::ApiResponse do
  let(:valid_data) { { "data" => "foo" } }

  let(:invalid_response_attr) { { "api_response" => { "ok" => false, "val" => valid_data } } }
  let(:valid_response_attr) { { "api_response" => { "ok" => true, "val" => valid_data } } }

  describe "#unwrap_response" do
    it "raises runtime error if api_response is not defined" do
      assert_raises(RuntimeError, "incomplete api response") { TestResponse.new.unwrap_response }
    end

    it "requires an ok==true bridge api_response" do
      resp_obj = TestResponse.new
      resp_obj.api_response = invalid_response_attr
      assert_raises(RuntimeError, "incomplete api response") { resp_obj.unwrap_response }

      resp_obj.api_response = valid_response_attr
      assert_equal({ "data" => "foo" }, resp_obj.unwrap_response)
    end
  end

  describe "nested attributes" do
    let(:valid_data) do
      { "data" => { "type" => "appleType",
                    "id" => "some-apple-id",
                    "attributes" => { "foo" => "bar" } } }
    end

    let(:resp_obj) do
      r = TestResponse.new
      r.api_response = valid_response_attr
      r
    end

    it "should have apple_data" do
      assert_equal({ "type" => "appleType",
                     "id" => "some-apple-id",
                     "attributes" => { "foo" => "bar" } }, resp_obj.apple_data)

      assert_equal("some-apple-id", resp_obj.apple_id)
      assert_equal("appleType", resp_obj.apple_type)
      assert_equal({ "foo" => "bar" }, resp_obj.apple_attributes)
    end
  end
end
