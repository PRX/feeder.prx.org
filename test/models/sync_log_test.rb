# frozen_string_literal: true

require "test_helper"

describe SyncLog do
  describe "indexes" do
    it "prevents the same feeder_type, feeder_id combination from being saved" do
      s = SyncLog.new(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})
      s.save!
      s2 = SyncLog.new(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})
      assert_raises ActiveRecord::RecordNotUnique do
        s2.save!
      end
    end
  end
  describe ".feeds" do
    it "filters records by a feeds enum" do
      s = SyncLog.new(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})
      s.save!
      assert_equal SyncLog.feeds, [s]
    end
  end

  describe ".log!" do
    it "creates a new record" do
      assert_difference "SyncLog.count", 1 do
        SyncLog.log!(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})
      end

      s = SyncLog.last
      assert_equal s.integration, "apple"
      assert_equal s.feeder_type, "feeds"
      assert_equal s.feeder_id, 123
      assert_equal s.external_id, "456"
      assert_equal s.api_response, {foo: "bar"}.as_json
    end

    it "updates an existing record" do
      s = SyncLog.create!(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})

      # Store the original updated_at
      original_updated_at = s.updated_at

      # Time travel to simulate passage of time
      travel 1.minute

      assert_no_difference "SyncLog.count" do
        SyncLog.log!(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "baz"})
      end

      s.reload
      assert_equal s.api_response, {foo: "baz"}.as_json
      assert_not_equal original_updated_at, s.updated_at, "updated_at should be explicitly updated"
    end
  end
end
