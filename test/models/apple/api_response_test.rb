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

  describe "joins" do
    let(:row_results) do
      [
        {"request_metadata" => {"apple_episode_id" => "1", "bar" => "111"}, "api_response" => {"foo" => "111"}},
        {"request_metadata" => {"apple_episode_id" => "2", "bar" => "222"}, "api_response" => {"foo" => "222"}},
        {"request_metadata" => {"apple_episode_id" => "3", "bar" => "333"}, "api_response" => {"foo" => "333"}}
      ]
    end

    let(:resources) do
      [
        OpenStruct.new(apple_episode_id: "1", bar: "111"),
        OpenStruct.new(apple_episode_id: "2", bar: "222"),
        OpenStruct.new(apple_episode_id: "3", bar: "333")
      ]
    end

    describe "many to one joins" do
      it "joins on apple_episode_id" do
        zipped = TestResponse.join_many_on("apple_episode_id", resources, row_results)
        assert zipped.length == 3
        # Still have a pair of resource and rows
        assert(zipped.all? { |r| r.length == 2 })

        # But the returned rows are now an array
        assert_equal zipped[0][1].length, 1
      end

      it "can join a single key against multiple results" do
        row_results << {"request_metadata" => {"apple_episode_id" => "1", "bar" => "777"}, "api_response" => {"foo" => "999"}}
        zipped = TestResponse.join_many_on("apple_episode_id", resources, row_results)
        assert zipped.length == 3

        assert_equal zipped[0][1].length, 2
        # The resource not an array
        assert_equal zipped[0][0].apple_episode_id, "1"
        assert_equal zipped[0][0].bar, "111"

        # Can return more than one api result per resource
        assert_equal zipped[0][1].map { |r| r["api_response"]["foo"] }, ["111", "999"]
        assert_equal zipped[0][1].map { |r| r["request_metadata"]["bar"] }, ["111", "777"]
      end
    end

    describe "one to one joins" do
      it "throws when the join results in more than one result" do
        row_results << {"request_metadata" => {"apple_episode_id" => "3", "bar" => "333"}, "api_response" => {"foo" => "444"}}
        assert_raises(RuntimeError, "Duplicate results found for 'bar'") { TestResponse.join_on("bar", resources, row_results) }
      end

      it "throws when the join results in no results" do
        assert_raises(RuntimeError, "Resource missing join attribute") { TestResponse.join_on("baz", resources, row_results) }
      end

      it "throws when the join results in partial results" do
        row_results << {"request_metadata" => {"apple_episode_id" => "4", "bar" => "444"}, "api_response" => {"foo" => "444"}}
        assert_raises(RuntimeError, "Join key mismatch") { TestResponse.join_on("bar", resources, row_results) }
      end
    end

    describe ".join_on_apple_episode_id" do
      it "uses the request metadata to join a set of resources responging to `apple_episode_id`" do
        zipped = TestResponse.join_on_apple_episode_id(resources, row_results)

        assert zipped.length == 3
        assert(zipped.all? { |r| r.length == 2 })

        zipped.each_with_index do |(resource, row), index|
          assert row["request_metadata"]["apple_episode_id"] == resource.apple_episode_id

          assert row["request_metadata"]["apple_episode_id"] == row_results[index]["request_metadata"]["apple_episode_id"]
          assert resource.apple_episode_id == resources[index].apple_episode_id
        end
      end
    end
  end
end
