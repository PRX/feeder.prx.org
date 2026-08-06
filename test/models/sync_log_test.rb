# frozen_string_literal: true

require "test_helper"

describe SyncLog do
  describe "integration STI" do
    it "uses the Apple subclass for new and persisted Apple rows" do
      sync_log = SyncLog.create!(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: "show-1")

      assert_instance_of Apple::SyncLog, sync_log
      assert_instance_of Apple::SyncLog, SyncLog.find(sync_log.id)
      assert_equal [sync_log], Apple::SyncLog.where(id: sync_log.id)
    end

    it "uses the Megaphone subclass for new and persisted Megaphone rows" do
      sync_log = SyncLog.create!(integration: :megaphone, feeder_type: :episodes, feeder_id: 123, external_id: "episode-1")

      assert_instance_of SyncLog, sync_log
      assert_instance_of SyncLog, SyncLog.find(sync_log.id)
      assert_equal [sync_log], SyncLog.megaphone.where(id: sync_log.id)
    end

    it "owns the integration for Apple log writes" do
      sync_log = Apple::SyncLog.log!(feeder_type: :feeds, feeder_id: 123, external_id: "show-1", api_response: {})

      assert_instance_of Apple::SyncLog, sync_log
      assert_equal "apple", sync_log.integration
    end

    it "does not allow Apple log writes to select another integration" do
      sync_log = Apple::SyncLog.log!(integration: :megaphone, feeder_type: :feeds, feeder_id: 123, external_id: "show-1", api_response: {})

      assert_instance_of Apple::SyncLog, sync_log
      assert_equal "apple", sync_log.integration
    end
  end

  describe "indexes" do
    it "uses Apple show identity in the unique index" do
      index = ActiveRecord::Base.connection.indexes(:sync_logs).find do |candidate|
        candidate.name == "idx_sync_logs_unique_by_external_show"
      end

      assert index.unique
      assert index.nulls_not_distinct
      assert_nil index.where
      assert_equal %w[integration feeder_type feeder_id external_show_id], index.columns
    end

    it "prevents duplicate unscoped sync logs" do
      SyncLog.create!(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 456, api_response: {foo: "bar"})
      s2 = SyncLog.new(integration: :apple, feeder_type: :feeds, feeder_id: 123, external_id: 789, api_response: {foo: "bar"})

      assert_raises ActiveRecord::RecordNotUnique do
        s2.save!
      end
    end

    it "prevents duplicate sync logs for the same apple show" do
      SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", external_show_id: "show-1")
      s2 = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", external_show_id: "show-1")

      assert_raises ActiveRecord::RecordNotUnique do
        s2.save!(validate: false)
      end
    end

    it "allows different shows to share a feeder" do
      SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", external_show_id: "show-1")

      assert_difference "SyncLog.count", 1 do
        SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", external_show_id: "show-2")
      end
    end
  end

  describe "Apple episode identity validation" do
    it "requires a show for a new Apple episode row" do
      sync_log = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1")

      assert_not sync_log.valid?
      assert sync_log.errors.of_kind?(:external_show_id, :blank)
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
      assert_nil s.external_show_id
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

    it "updates the external id within an existing identity" do
      sync_log = SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", external_show_id: "show-1", api_response: {})

      assert_no_difference "SyncLog.count" do
        updated = SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", external_show_id: "show-1", api_response: {})

        assert_equal sync_log.id, updated.id
        assert_equal "ep-2", updated.external_id
      end
    end

    it "creates a scoped row when an apple show id is provided" do
      assert_difference "SyncLog.count", 1 do
        SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", external_show_id: "show-1", api_response: {foo: "bar"})
      end

      assert_equal "show-1", SyncLog.last.external_show_id
    end

    it "creates a separate row for a second show" do
      SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", external_show_id: "show-1", api_response: {foo: "bar"})

      assert_difference "SyncLog.count", 1 do
        SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", external_show_id: "show-2", api_response: {foo: "baz"})
      end

      assert_equal ["show-1", "show-2"], SyncLog.apple.episodes.where(feeder_id: 123).order(:external_show_id).pluck(:external_show_id)
    end
  end
end
