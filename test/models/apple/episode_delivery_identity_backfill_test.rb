# frozen_string_literal: true

require "test_helper"

module Apple
  describe EpisodeDeliveryIdentityBackfill do
    describe ".backfill!" do
      it "stamps every Apple delivery-state row from the show feed binding" do
        state = create_unscoped_state(apple_show_id: "show-from-binding")

        report = EpisodeDeliveryIdentityBackfill.backfill!

        assert_equal({episode_sync_logs: 1, podcast_containers: 1, delivery_statuses: 1}, report[:row_counts])
        assert_equal({episode_sync_logs: 1, podcast_containers: 1, delivery_statuses: 1}, report[:unscoped_counts])
        assert_equal 3, report[:updated]
        assert_equal 3, report[:changed]
        assert_equal "show-from-binding", state[:sync_log].reload.apple_show_id
        assert_equal "show-from-binding", state[:podcast_container].reload.apple_show_id
        assert_equal "show-from-binding", state[:delivery_status].reload.apple_show_id
      end

      it "does not use a conflicting legacy show id" do
        state = create_unscoped_state(apple_show_id: "show-from-binding")
        state[:podcast].public_feed.update!(apple_show_id: "legacy-feed-show")
        SyncLog.log!(
          integration: :apple,
          feeder_type: :feeds,
          feeder_id: state[:podcast].public_feed.id,
          external_id: "legacy-sync-show"
        )

        EpisodeDeliveryIdentityBackfill.backfill!

        assert_equal "show-from-binding", state[:sync_log].reload.apple_show_id
        assert_equal "show-from-binding", state[:podcast_container].reload.apple_show_id
        assert_equal "show-from-binding", state[:delivery_status].reload.apple_show_id
      end

      it "backfills state for a soft-deleted episode" do
        state = create_unscoped_state(apple_show_id: "show-deleted")
        state[:episode].destroy!

        EpisodeDeliveryIdentityBackfill.backfill!

        assert_equal "show-deleted", state[:sync_log].reload.apple_show_id
        assert_equal "show-deleted", state[:podcast_container].reload.apple_show_id
        assert_equal "show-deleted", state[:delivery_status].reload.apple_show_id
      end

      it "skips and reports rows whose binding precondition is not satisfied" do
        missing_episode = create_legacy_sync_log(feeder_id: -1, external_id: "missing-episode")
        missing_config = create_unscoped_state(with_config: false)[:sync_log]
        missing_binding = create_unscoped_state(with_binding: false)[:sync_log]
        ambiguous_binding = create_unscoped_state(ambiguous_binding: true)[:sync_log]

        report = EpisodeDeliveryIdentityBackfill.backfill!

        skipped_sync_logs = report[:skipped_rows].select { |row| row[:record_type] == :episode_sync_logs }
        assert_equal 4, skipped_sync_logs.length
        assert_equal [missing_episode.id, missing_config.id, missing_binding.id, ambiguous_binding.id].sort,
          skipped_sync_logs.map { |row| row[:record_id] }.sort
        assert_equal 2, skipped_sync_logs.count { |row| row[:reason] == "missing episode or Apple config" }
        assert_includes skipped_sync_logs.map { |row| row[:reason] }, "missing show feed binding"
        assert skipped_sync_logs.any? { |row| row[:reason].start_with?("ambiguous show feed bindings:") }
      end

      it "is idempotent" do
        create_unscoped_state
        EpisodeDeliveryIdentityBackfill.backfill!

        assert_no_difference ["SyncLog.count", "Apple::PodcastContainer.count", "Integrations::EpisodeDeliveryStatus.count"] do
          report = EpisodeDeliveryIdentityBackfill.backfill!

          assert_equal({episode_sync_logs: 0, podcast_containers: 0, delivery_statuses: 0}, report[:unscoped_counts])
          assert_equal 0, report[:updated]
          assert_equal 0, report[:changed]
          assert_empty report[:actions]
        end
      end

      it "can dry run without writing" do
        state = create_unscoped_state

        report = EpisodeDeliveryIdentityBackfill.backfill!(dry_run: true)

        assert_equal 3, report[:updated]
        assert_equal ["would_update"], report[:actions].map { |action| action[:action] }.uniq
        assert_nil state[:sync_log].reload.apple_show_id
        assert_nil state[:podcast_container].reload.apple_show_id
        assert_nil state[:delivery_status].reload.apple_show_id
      end

      it "leaves non-Apple delivery status rows unscoped" do
        state = create_unscoped_state
        megaphone_status = create(:megaphone_episode_delivery_status, episode: state[:episode])

        EpisodeDeliveryIdentityBackfill.backfill!

        assert_nil megaphone_status.reload.apple_show_id
      end
    end

    describe ".verify!" do
      it "reports remaining null, mismatched, and unresolvable rows" do
        null_state = create_unscoped_state(apple_show_id: "show-null")
        mismatched_state = create_unscoped_state(apple_show_id: "show-expected")
        mismatched_state[:podcast_container].update_columns(apple_show_id: "show-wrong")
        missing_episode = create_legacy_sync_log(feeder_id: -1, external_id: "missing-episode", apple_show_id: "show-orphan")

        report = EpisodeDeliveryIdentityBackfill.verify!

        assert_includes report[:remaining_null_show_rows][:episode_sync_logs].map { |row| row[:record_id] }, null_state[:sync_log].id
        assert_includes report[:remaining_null_show_rows][:podcast_containers].map { |row| row[:record_id] }, null_state[:podcast_container].id
        assert_includes report[:remaining_null_show_rows][:delivery_statuses].map { |row| row[:record_id] }, null_state[:delivery_status].id
        assert_includes report[:mismatched_show_rows].map { |row| row[:record_id] }, mismatched_state[:podcast_container].id
        assert_includes report[:resolution_errors].map { |row| row[:record_id] }, missing_episode.id
      end

      it "is clean after a successful backfill" do
        create_unscoped_state
        EpisodeDeliveryIdentityBackfill.backfill!

        report = EpisodeDeliveryIdentityBackfill.verify!

        assert report[:remaining_null_show_rows].values.all?(&:empty?)
        assert_empty report[:mismatched_show_rows]
        assert_empty report[:resolution_errors]
      end
    end

    def create_unscoped_state(apple_show_id: "show-1", with_config: true, with_binding: true, ambiguous_binding: false)
      podcast = create(:podcast)
      private_feed = create(:private_feed, podcast: podcast)
      config = create(:apple_config, feed: private_feed) if with_config

      if config && with_binding
        binding = create(:apple_show_feed_binding, feed: podcast.public_feed, apple_show_id: apple_show_id)
        config.update!(show_feed_binding: binding)

        if ambiguous_binding
          another_private_feed = create(:private_feed, podcast: podcast)
          another_config = build(:apple_config, feed: another_private_feed)
          another_config.save!(validate: false)
          another_public_feed = create(:feed, podcast: podcast, private: false, slug: "another-public", label: "Another public feed")
          another_binding = create(:apple_show_feed_binding, feed: another_public_feed, apple_show_id: "another-show")
          another_config.update_column(:show_feed_binding_id, another_binding.id)
        end
      end

      episode = create(:episode, podcast: podcast)
      sync_log = create_legacy_sync_log(feeder_id: episode.id, external_id: "episode-#{episode.id}")
      podcast_container = create(:apple_podcast_container, episode: episode)
      delivery_status = create(:apple_episode_delivery_status, episode: episode)

      {
        podcast: podcast,
        episode: episode,
        sync_log: sync_log,
        podcast_container: podcast_container,
        delivery_status: delivery_status
      }
    end

    def create_legacy_sync_log(**attrs)
      sync_log = SyncLog.new(integration: :apple, feeder_type: :episodes, **attrs)
      sync_log.save!(validate: false)
      sync_log
    end
  end
end
