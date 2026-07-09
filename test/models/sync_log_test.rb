# frozen_string_literal: true

require "test_helper"

describe SyncLog do
  describe "indexes" do
    it "retains one SyncLog row per feeder during show scoping" do
      index = ActiveRecord::Base.connection.indexes(:sync_logs).find do |candidate|
        candidate.name == "index_sync_logs_on_integration_and_feeder_type_and_feeder_id"
      end

      assert index.unique
      assert_nil index.where
      assert_equal %w[integration feeder_type feeder_id], index.columns
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
        s2.save!(validate: false)
      end
    end

    it "prevents different shows from sharing a feeder during show scoping" do
      SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1")
      s2 = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", apple_show_id: "show-2")

      assert_raises ActiveRecord::RecordNotUnique do
        s2.save!(validate: false)
      end
    end
  end

  describe "Apple episode identity validation" do
    it "requires a show for a new Apple episode row" do
      sync_log = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1")

      assert_not sync_log.valid?
      assert sync_log.errors.of_kind?(:apple_show_id, :blank)
    end

    it "rejects a scoped row alongside a legacy row" do
      create_legacy_apple_episode_sync_log(feeder_id: 123, external_id: "ep-1")
      scoped = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1")

      assert_not scoped.valid?
      assert_includes scoped.errors[:feeder_id], "already has an Apple episode sync log"
    end

    it "rejects a legacy row alongside a scoped row" do
      SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1")
      legacy = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1")

      assert_not legacy.valid?
      assert_includes legacy.errors[:feeder_id], "already has an Apple episode sync log"
    end

    it "allows a legacy row to be scoped in place" do
      legacy = create_legacy_apple_episode_sync_log(feeder_id: 123, external_id: "ep-1")

      assert_nothing_raised do
        legacy.update!(apple_show_id: "show-1")
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

    it "rejects modifying a legacy row without assigning its show" do
      s = create_legacy_apple_episode_sync_log(feeder_id: 123, external_id: "ep-1", api_response: {foo: "bar"})

      assert_no_difference "SyncLog.count" do
        assert_raises ActiveRecord::RecordInvalid do
          SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: nil, api_response: {foo: "baz"})
        end
      end

      assert_nil s.reload.apple_show_id
      assert_equal({foo: "bar"}.as_json, s.api_response)
    end

    it "creates a scoped row when an apple show id is provided" do
      assert_difference "SyncLog.count", 1 do
        SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1", api_response: {foo: "bar"})
      end

      assert_equal "show-1", SyncLog.last.apple_show_id
    end

    it "rejects a second show for the same feeder during show scoping" do
      SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1", api_response: {foo: "bar"})

      assert_no_difference "SyncLog.count" do
        assert_raises ActiveRecord::RecordInvalid do
          SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-2", apple_show_id: "show-2", api_response: {foo: "baz"})
        end
      end
    end

    it "claims a matching legacy row instead of creating a duplicate" do
      legacy = create_legacy_apple_episode_sync_log(feeder_id: 123, external_id: "ep-1", api_response: {foo: "bar"})

      assert_no_difference "SyncLog.count" do
        logged = SyncLog.log!(integration: :apple, feeder_type: :episodes, feeder_id: 123, external_id: "ep-1", apple_show_id: "show-1", api_response: {foo: "baz"})

        assert_equal legacy.id, logged.id
      end

      legacy.reload
      assert_equal "show-1", legacy.apple_show_id
      assert_equal({foo: "baz"}.as_json, legacy.api_response)
    end
  end

  def create_legacy_apple_episode_sync_log(**attrs)
    sync_log = SyncLog.new(integration: :apple, feeder_type: :episodes, **attrs)
    sync_log.save!(validate: false)
    sync_log
  end
end
