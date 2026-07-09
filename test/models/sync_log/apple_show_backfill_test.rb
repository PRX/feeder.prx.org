# frozen_string_literal: true

require "test_helper"

class SyncLog
  describe AppleShowBackfill do
    describe ".backfill!" do
      it "resolves the apple show id from the public feed sync log" do
        sync_log = create_legacy_episode_sync_log(sync_log_show_id: "show-from-sync")

        report = AppleShowBackfill.backfill!

        assert_equal 1, report[:updated]
        assert_equal 1, report[:changed]
        assert_equal "show-from-sync", sync_log.reload.apple_show_id
      end

      it "falls back to the private feed apple show id" do
        sync_log = create_legacy_episode_sync_log(private_show_id: "show-from-feed")

        AppleShowBackfill.backfill!

        assert_equal "show-from-feed", sync_log.reload.apple_show_id
      end

      it "skips and reports unresolvable rows" do
        missing_episode = SyncLog.create!(integration: :apple, feeder_type: :episodes, feeder_id: -1, external_id: "missing-episode")
        missing_config = create_legacy_episode_sync_log(with_config: false)
        missing_show_id = create_legacy_episode_sync_log

        report = AppleShowBackfill.backfill!

        assert_equal 3, report[:skipped]
        assert_equal [missing_episode.id, missing_config.id, missing_show_id.id].sort, report[:skipped_sync_logs].map { |row| row[:sync_log_id] }.sort
        assert_includes report[:skipped_sync_logs].map { |row| row[:reason] }, "missing episode"
        assert_includes report[:skipped_sync_logs].map { |row| row[:reason] }, "missing config"
        assert_includes report[:skipped_sync_logs].map { |row| row[:reason] }, "missing show id"
      end

      it "is idempotent" do
        create_legacy_episode_sync_log(sync_log_show_id: "show-from-sync")
        AppleShowBackfill.backfill!

        assert_no_difference "SyncLog.count" do
          report = AppleShowBackfill.backfill!

          assert_equal 0, report[:sync_logs_total]
          assert_equal 0, report[:updated]
          assert_equal 0, report[:changed]
          assert_empty report[:actions]
        end
      end

      it "can dry run without writing" do
        sync_log = create_legacy_episode_sync_log(sync_log_show_id: "show-from-sync")

        report = AppleShowBackfill.backfill!(dry_run: true)

        assert_equal 1, report[:updated]
        assert_equal "would_update", report[:actions].first[:action]
        assert_nil sync_log.reload.apple_show_id
      end
    end

    describe ".verify!" do
      it "flags invariant violations after backfill" do
        sync_log = create_legacy_episode_sync_log(sync_log_show_id: "show-from-sync")
        SyncLog.create!(integration: :apple,
          feeder_type: :episodes,
          feeder_id: sync_log.feeder_id,
          external_id: "scoped-episode",
          apple_show_id: "show-from-sync")

        report = AppleShowBackfill.verify!

        assert_equal [sync_log.id], report[:remaining_null_show_episode_rows].map { |row| row[:sync_log_id] }
        assert_equal [{feeder_id: sync_log.feeder_id, count: 2}], report[:multi_row_episode_feeder_ids]
      end
    end

    def create_legacy_episode_sync_log(sync_log_show_id: nil, private_show_id: nil, with_config: true)
      podcast = create(:podcast)
      private_feed = create(:private_feed, podcast: podcast, apple_show_id: private_show_id)
      create(:apple_config, feed: private_feed) if with_config
      episode = create(:episode, podcast: podcast)

      if sync_log_show_id
        SyncLog.log!(
          integration: :apple,
          feeder_type: :feeds,
          feeder_id: podcast.public_feed.id,
          external_id: sync_log_show_id
        )
      end

      SyncLog.create!(integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "episode-#{episode.id}")
    end
  end
end
