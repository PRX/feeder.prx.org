# frozen_string_literal: true

require "test_helper"

describe SyncLog do
  describe "indexes" do
    it "uses one full unique index that supports the legacy lookup prefix" do
      index = ActiveRecord::Base.connection.indexes(:sync_logs).find do |candidate|
        candidate.name == "idx_sync_logs_unique_by_apple_show"
      end

      assert index.unique
      assert index.nulls_not_distinct
      assert_nil index.where
      assert_equal %w[integration feeder_type feeder_id apple_show_id], index.columns
    end

    it "prevents duplicate unscoped sync logs" do
      SyncLog.create!(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})
      s2 = SyncLog.new(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 789, api_response: {foo: "bar"})

      assert_raises ActiveRecord::RecordNotUnique do
        s2.save!
      end
    end

    it "prevents duplicate sync logs for the same apple show" do
      SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1")
      s2 = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", apple_show_id: "show-1")

      assert_raises ActiveRecord::RecordNotUnique do
        s2.save!
      end
    end

    it "allows the same feeder to be scoped to different apple shows" do
      SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1")

      assert_difference "SyncLog.count", 1 do
        SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", apple_show_id: "show-2")
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
      assert_nil s.apple_show_id
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

    it "treats a nil apple show id as the legacy unscoped identity" do
      s = SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", api_response: {foo: "bar"})

      assert_no_difference "SyncLog.count" do
        logged = SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: nil, api_response: {foo: "baz"})

        assert_equal s.id, logged.id
      end

      assert_nil s.reload.apple_show_id
      assert_equal({foo: "baz"}.as_json, s.api_response)
    end

    it "creates a scoped row when an apple show id is provided" do
      assert_difference "SyncLog.count", 1 do
        SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1", api_response: {foo: "bar"})
      end

      assert_equal "show-1", SyncLog.last.apple_show_id
    end

    it "creates separate rows for the same feeder on two apple shows" do
      SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1", api_response: {foo: "bar"})

      assert_difference "SyncLog.count", 1 do
        SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", apple_show_id: "show-2", api_response: {foo: "baz"})
      end

      assert_equal ["show-1", "show-2"], SyncLog.apple.episodes.where(feeder_id: 123).order(:apple_show_id).pluck(:apple_show_id)
    end

    it "claims a matching legacy row instead of creating a duplicate" do
      legacy = SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", api_response: {foo: "bar"})

      assert_no_difference "SyncLog.count" do
        logged = SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1", api_response: {foo: "baz"})

        assert_equal legacy.id, logged.id
      end

      legacy.reload
      assert_equal "show-1", legacy.apple_show_id
      assert_equal({foo: "baz"}.as_json, legacy.api_response)
    end
  end
end
