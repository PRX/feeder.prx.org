require "test_helper"

module Apple
  describe ShowFeedBinding::Backfill do
    describe ".backfill!" do
      it "creates a binding and sets the config from a public feed sync log" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync", private_show_id: "show-from-feed")

        report = ShowFeedBinding::Backfill.backfill!

        binding = config.public_feed.apple_show_feed_binding
        assert_equal 1, report[:created]
        assert_equal 1, report[:linked]
        assert_equal binding, config.reload.show_feed_binding
        assert_equal config.public_feed, binding.feed
        assert_equal config.key, config.podcast.apple_key
        assert_equal "show-from-sync", binding.apple_show_id
      end

      it "falls back to the private feed apple show id" do
        config = create_config_with_legacy_show_id(private_show_id: "show-from-feed")

        ShowFeedBinding::Backfill.backfill!

        assert_equal "show-from-feed", config.reload.show_feed_binding.apple_show_id
      end

      it "skips and reports configs missing a key or show id" do
        missing_key = create_config_with_legacy_show_id(private_show_id: "show-without-key", key: nil)
        missing_show_id = create_config_with_legacy_show_id

        report = ShowFeedBinding::Backfill.backfill!

        assert_equal 2, report[:skipped]
        assert_equal [missing_key.id, missing_show_id.id].sort, report[:skipped_configs].map { |row| row[:config_id] }.sort
        assert_includes report[:skipped_configs].map { |row| row[:reason] }, "missing key"
        assert_includes report[:skipped_configs].map { |row| row[:reason] }, "missing show id"
      end

      it "is idempotent" do
        create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")
        ShowFeedBinding::Backfill.backfill!

        assert_no_difference "ShowFeedBinding.count" do
          report = ShowFeedBinding::Backfill.backfill!

          assert_equal 0, report[:changed]
          assert_equal 0, report[:created]
          assert_equal 0, report[:updated]
          assert_equal 0, report[:linked]
        end
      end

      it "can dry run without writing" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")

        assert_no_difference "ShowFeedBinding.count" do
          report = ShowFeedBinding::Backfill.backfill!(dry_run: true)

          assert_equal 1, report[:created]
          assert_equal 1, report[:linked]
          assert_equal "would_create", report[:actions].first[:action]
        end
        assert_nil config.reload.show_feed_binding
        assert_nil config.podcast.reload.apple_key
      end

      it "reports conflicting podcast key candidates without choosing one" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")
        other_feed = create(:private_feed, podcast: config.podcast)
        other_config = build(:delegated_delivery_config, feed: other_feed, key: create(:apple_key))
        other_config.save!(validate: false)
        config.podcast.update_column(:apple_key_id, nil)

        report = ShowFeedBinding::Backfill.backfill!

        assert_equal 1, report[:key_conflicts].length
        assert_equal [config.id, other_config.id].sort, report[:key_conflicts].first[:config_ids].sort
        assert_nil config.podcast.reload.apple_key
        assert_nil config.reload.show_feed_binding
      end

      it "reports duplicate binding claims without choosing a config" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")
        other_config = build(
          :delegated_delivery_config,
          feed: create(:private_feed, podcast: config.podcast),
          key: config.key
        )
        other_config.save!(validate: false)

        report = ShowFeedBinding::Backfill.backfill!

        assert_equal 1, report[:binding_conflicts].length
        assert_equal config.public_feed.id, report[:binding_conflicts].first[:feed_id]
        assert_equal [config.id, other_config.id].sort, report[:binding_conflicts].first[:config_ids]
        assert_equal 2, report[:skipped]
        assert_nil config.reload.show_feed_binding
        assert_nil other_config.reload.show_feed_binding
      end
    end

    describe ".verify_routing_equivalence!" do
      it "reports zero mismatches after backfill" do
        create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")
        ShowFeedBinding::Backfill.backfill!

        report = ShowFeedBinding::Backfill.verify_routing_equivalence!

        assert_empty report[:mismatches]
      end

      it "reports a seeded mismatch" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")
        ShowFeedBinding::Backfill.backfill!
        config.reload.show_feed_binding.update!(apple_show_id: "wrong-show")

        report = ShowFeedBinding::Backfill.verify_routing_equivalence!

        assert_equal 1, report[:mismatches].length
        assert_equal config.id, report[:mismatches].first[:config_id]
        assert_equal "apple_show_id", report[:mismatches].first[:mismatches].first[:field]
      end

      it "reports a podcast key mismatch" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-from-sync")
        ShowFeedBinding::Backfill.backfill!
        replacement_key = create(:apple_key, account_id: config.podcast.account_id)
        config.podcast.update!(apple_key: replacement_key)

        report = ShowFeedBinding::Backfill.verify_routing_equivalence!

        assert_equal 1, report[:mismatches].length
        assert_equal config.id, report[:mismatches].first[:config_id]
        assert_equal "podcast.apple_key_id", report[:mismatches].first[:mismatches].first[:field]
      end
    end

    describe ".verify_episode_show_consistency!" do
      it "reports zero mismatches when every legacy episode id belongs to the bound show" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-1")
        ShowFeedBinding::Backfill.backfill!
        sync_log = create_legacy_episode_sync_log(config)

        report = with_remote_episode_ids(sync_log.external_id) do
          ShowFeedBinding::Backfill.verify_episode_show_consistency!
        end

        assert_equal 1, report[:configs_total]
        assert_equal 1, report[:episode_sync_logs_total]
        assert_empty report[:mismatches]
        assert_empty report[:errors]
      end

      it "reports an episode id that does not belong to the bound show" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-1")
        ShowFeedBinding::Backfill.backfill!
        sync_log = create_legacy_episode_sync_log(config)

        report = with_remote_episode_ids("another-episode") do
          ShowFeedBinding::Backfill.verify_episode_show_consistency!
        end

        assert_equal 1, report[:mismatches].length
        assert_equal sync_log.id, report[:mismatches].first[:sync_log_id]
        assert_equal "show-1", report[:mismatches].first[:apple_show_id]
      end

      it "reports Apple lookup failures without assigning episode state" do
        config = create_config_with_legacy_show_id(sync_log_show_id: "show-1")
        ShowFeedBinding::Backfill.backfill!
        sync_log = create_legacy_episode_sync_log(config)
        loader = ->(*) { raise "Apple unavailable" }

        report = Apple::Show.stub(:apple_episode_json, loader) do
          ShowFeedBinding::Backfill.verify_episode_show_consistency!
        end

        assert_equal 1, report[:errors].length
        assert_match(/Apple show episode verification failed/, report[:errors].first[:reason])
        assert_equal sync_log, SyncLog.find(sync_log.id)
      end
    end

    def create_config_with_legacy_show_id(sync_log_show_id: nil, private_show_id: nil, key: create(:apple_key))
      podcast_attributes = key ? {prx_account_uri: "/api/v1/accounts/#{key.account_id}"} : {}
      podcast = create(:podcast, **podcast_attributes)
      private_feed = create(:private_feed, podcast: podcast, apple_show_id: private_show_id)
      config = create(:delegated_delivery_config, feed: private_feed, key: key)
      podcast.update_column(:apple_key_id, nil)

      if sync_log_show_id
        SyncLog.log!(
          integration: :apple,
          feeder_type: :feeds,
          feeder_id: podcast.public_feed.id,
          external_id: sync_log_show_id
        )
      end

      config
    end

    def create_legacy_episode_sync_log(config)
      episode = create(:episode, podcast: config.podcast)
      sync_log = SyncLog.new(
        integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "episode-#{episode.id}"
      )
      sync_log.save!(validate: false)
      sync_log
    end

    def with_remote_episode_ids(*episode_ids, &block)
      remote_episodes = episode_ids.map { |episode_id| {"id" => episode_id.to_s} }
      Apple::Show.stub(:apple_episode_json, remote_episodes, &block)
    end
  end
end
