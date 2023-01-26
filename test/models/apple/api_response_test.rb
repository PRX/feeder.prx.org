# frozen_string_literal: true

require "test_helper"

class TestResponse
  include Apple::ApiResponse
  attr_accessor :api_response
end

describe Apple::ApiResponse do
  let(:valid_data) { {"data" => "foo"} }

  let(:invalid_response_attr) { {"api_response" => {"ok" => false, "val" => valid_data}} }
  let(:valid_response_attr) { {"api_response" => {"ok" => true, "val" => valid_data}} }

  describe "#unwrap_response" do
    it "raises runtime error if api_response is not defined" do
      assert_raises(RuntimeError, "incomplete api response") { TestResponse.new.unwrap_response }
    end

    it "requires an ok==true bridge api_response" do
      resp_obj = TestResponse.new
      resp_obj.api_response = invalid_response_attr
      assert_raises(RuntimeError, "incomplete api response") { resp_obj.unwrap_response }

      resp_obj.api_response = valid_response_attr
      assert_equal({"data" => "foo"}, resp_obj.unwrap_response)
    end
  end

  describe "nested attributes" do
    let(:valid_data) do
      {"data" => {"type" => "appleType",
                  "id" => "some-apple-id",
                  "attributes" => {"foo" => "bar"}}}
    end

    let(:resp_obj) do
      r = TestResponse.new
      r.api_response = valid_response_attr
      r
    end

    it "should have apple_data" do
      assert_equal({"type" => "appleType",
                     "id" => "some-apple-id",
                     "attributes" => {"foo" => "bar"}}, resp_obj.apple_data)

      assert_equal("some-apple-id", resp_obj.apple_id)
      assert_equal("appleType", resp_obj.apple_type)
      assert_equal({"foo" => "bar"}, resp_obj.apple_attributes)
    end
  end

  describe ".join_on_apple_episode_id" do
    it "uses the request metadata to join a set of resources responging to `apple_episode_id`" do
      row_results = [{request_metadata: {apple_episode_id: "1"}, api_response: {foo: "111"}},
        {request_metadata: {apple_episode_id: "2"}, api_response: {foo: "222"}},
        {request_metadata: {apple_episode_id: "3"}, api_response: {foo: "333"}}]
      row_results = row_results.map(&:with_indifferent_access)

      resources = [
        OpenStruct.new(apple_episode_id: "1", bar: "111"),
        OpenStruct.new(apple_episode_id: "2", bar: "222"),
        OpenStruct.new(apple_episode_id: "3", bar: "333")
      ]

      zipped = TestResponse.join_on_apple_episode_id(resources, row_results)

      assert zipped.length == 3
      assert(zipped.all? { |r| r.length == 2 })

      zipped.each_with_index do |(resource, row), index|
        assert row[:request_metadata][:apple_episode_id] == resource.apple_episode_id

        assert row[:request_metadata][:apple_episode_id] == row_results[index][:request_metadata][:apple_episode_id]
        assert resource.apple_episode_id == resources[index].apple_episode_id
      end
    end
  end
end
