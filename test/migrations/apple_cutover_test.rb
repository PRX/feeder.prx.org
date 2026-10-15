require "test_helper"
require_relative "../../db/migrate/20260916000001_add_apple_cutover_constraints"

class AppleCutoverMigrationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
    @original_search_path = @connection.schema_search_path
    @schema = "apple_cutover_test_#{SecureRandom.hex(8)}"
    @connection.execute("CREATE SCHEMA #{@schema}")
    @connection.schema_search_path = @schema
    @connection.schema_cache.clear!
    @connection.create_table(:apple_configs) do |t|
      t.bigint :show_feed_binding_id
    end
    @connection.create_table(:sync_logs) do |t|
      t.integer :integration
      t.string :feeder_type, null: false
      t.bigint :feeder_id, null: false
      t.string :external_show_id
    end
    @connection.create_table(:apple_podcast_containers) do |t|
      t.bigint :episode_id
      t.string :apple_show_id
    end
    @connection.create_table(:integrations_episode_delivery_statuses) do |t|
      t.bigint :episode_id
      t.integer :integration
      t.string :apple_show_id
      t.datetime :created_at
    end
  end

  teardown do
    @connection.schema_search_path = @original_search_path
    @connection.execute("DROP SCHEMA #{@schema} CASCADE")
    @connection.schema_cache.clear!
  end

  test "cutover refuses data left unbackfilled then validates constraints and supports rollback" do
    @connection.execute("INSERT INTO sync_logs (integration, feeder_type, feeder_id) VALUES (0, 'episodes', 1)")
    @connection.execute("INSERT INTO apple_podcast_containers (episode_id) VALUES (1)")
    @connection.execute("INSERT INTO integrations_episode_delivery_statuses (episode_id, integration) VALUES (1, 0), (1, 1)")

    # Each missing identity independently prevents completing the cutover.
    [
      "UPDATE sync_logs SET external_show_id = 'show-1' WHERE integration = 0 AND feeder_type = 'episodes'",
      "UPDATE integrations_episode_delivery_statuses SET apple_show_id = 'show-1' WHERE integration = 0",
      "UPDATE apple_podcast_containers SET apple_show_id = 'show-1'"
    ].each do |backfill|
      assert_raises(ActiveRecord::StatementInvalid) do
        @connection.transaction { migrate AddAppleCutoverConstraints, :up }
      end
      @connection.execute(backfill)
    end

    @connection.transaction { migrate AddAppleCutoverConstraints, :up }
    assert @connection.check_constraints(:sync_logs).all?(&:validated?)
    assert @connection.check_constraints(:integrations_episode_delivery_statuses).all?(&:validated?)
    refute @connection.columns(:apple_configs).find { |column| column.name == "show_feed_binding_id" }.null
    refute @connection.columns(:apple_podcast_containers).find { |column| column.name == "apple_show_id" }.null
    assert_nil @connection.select_value("SELECT apple_show_id FROM integrations_episode_delivery_statuses WHERE integration = 1")

    @connection.transaction { migrate AddAppleCutoverConstraints, :down }
    assert @connection.columns(:apple_configs).find { |column| column.name == "show_feed_binding_id" }.null
    @connection.execute("UPDATE sync_logs SET external_show_id = NULL")
    @connection.execute("UPDATE apple_podcast_containers SET apple_show_id = NULL")
    @connection.execute("UPDATE integrations_episode_delivery_statuses SET apple_show_id = NULL")
  end

  test "cutover reports config IDs left without bindings" do
    @connection.execute("INSERT INTO apple_configs (id) VALUES (17), (23)")

    error = assert_raises(ActiveRecord::MigrationError) do
      @connection.transaction { migrate AddAppleCutoverConstraints, :up }
    end

    assert_includes error.message, "17, 23"
    assert @connection.columns(:apple_configs).find { |column| column.name == "show_feed_binding_id" }.null
  end

  private

  def migrate(migration, direction)
    # These isolated tables exercise constraint validation when backfills skip
    # unresolved rows. The integration test below exercises the real backfills.
    Apple::ShowFeedBinding::Backfill.stub(:backfill!, {}) do
      Apple::EpisodeDeliveryIdentityBackfill.stub(:backfill!, {}) do
        migration.suppress_messages { migration.new.migrate(direction) }
      end
    end
  end
end

class AppleCutoverBackfillMigrationTest < ActiveSupport::TestCase
  test "cutover backfills legacy routing and delivery identities before validating" do
    AddAppleCutoverConstraints.suppress_messages { AddAppleCutoverConstraints.new.migrate(:down) }

    podcast = create(:podcast)
    private_feed = create(:private_feed, podcast: podcast, apple_show_id: "show-1")
    config = build(:delegated_delivery_config, :legacy_routing, feed: private_feed)
    # Reproduce an unfinished setup saved before bindings were required.
    config.save!(validate: false)
    podcast.update_column(:apple_key_id, nil)
    episode = create(:episode, podcast: podcast)
    sync_log = SyncLog.new(integration: :apple, feeder_type: :episodes, feeder_id: episode.id, external_id: "episode-1")
    sync_log.save!(validate: false)
    container = build(:apple_podcast_container, episode: episode, apple_show_id: nil)
    container.save!(validate: false)
    status = build(:apple_episode_delivery_status, episode: episode, apple_show_id: nil)
    status.save!(validate: false)

    AddAppleCutoverConstraints.suppress_messages { AddAppleCutoverConstraints.new.migrate(:up) }

    assert_equal config.key_id, podcast.reload.apple_key_id
    assert_equal "show-1", config.reload.show_feed_binding.apple_show_id
    assert_equal "show-1", sync_log.reload.external_show_id
    assert_equal "show-1", container.reload.apple_show_id
    assert_equal "show-1", status.reload.apple_show_id
    connection = ActiveRecord::Base.connection
    assert connection.check_constraints(:sync_logs).all?(&:validated?)
    assert connection.check_constraints(:integrations_episode_delivery_statuses).all?(&:validated?)
    refute connection.columns(:apple_configs).find { |column| column.name == "show_feed_binding_id" }.null
    refute connection.columns(:apple_podcast_containers).find { |column| column.name == "apple_show_id" }.null
  end
end
