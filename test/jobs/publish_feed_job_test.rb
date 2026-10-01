require "test_helper"

describe PublishFeedJob do
  let(:stub_client) { Aws::S3::Client.new(stub_responses: true) }
  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }
  let(:feed) { create(:feed, podcast: podcast, slug: "adfree") }
  let(:private_feed) { create(:apple_feed, podcast: podcast) }

  let(:job) { PublishFeedJob.new }

  it "knows the right bucket to write to" do
    assert_equal job.s3_bucket, "test-prx-feed"
    ENV["FEEDER_STORAGE_BUCKET"] = "foo"
    assert_equal job.s3_bucket, "foo"
    ENV["FEEDER_STORAGE_BUCKET"] = "test-prx-feed"
  end

  describe "saving the rss file" do
    before do
      stub_request(:head, episode.enclosure_url).to_return(status: 200)
      stub_request(:get, /#{ENV["PODPING_HOST"]}/).to_return(status: 200)
    end

    describe "#perform" do
      it "transitions to the error state upon general error" do
        job.stub(:s3_client, stub_client) do
          pqi = PublishingPipelineState.start_pipeline!(podcast)
          # Simulate some method blowing up
          PublishingPipelineState.stub(:publish_rss!, ->(*, **) { raise "some general" }) do
            assert_raises(RuntimeError) { job.perform(podcast, pqi) }
            assert_equal ["created", "started", "error_rss", "error"], PublishingPipelineState.where(podcast: podcast).latest_pipelines.order(id: :asc).pluck(:status)
          end
        end
      end
    end

    it "can save a podcast file" do
      job.stub(:s3_client, stub_client) do
        refute_nil job.save_file(podcast, podcast.default_feed)
        refute_nil job.save_file(podcast, feed)
      end
    end

    describe "#update_first_publish_episodes" do
      it "only records a timestamp if it's published to the default feed" do
        assert_nil podcast.episodes.first.first_rss_published_at

        job.stub(:s3_client, stub_client) do
          job.save_file(podcast, feed)
          assert_nil podcast.episodes.first.first_rss_published_at
        end
      end

      it "records the timestamp when the episode is published to rss" do
        assert_nil podcast.episodes.first.first_rss_published_at

        job.stub(:s3_client, stub_client) do
          rss_builder = FeedBuilder.new(podcast, podcast.default_feed)
          job.after_publish_rss(podcast, podcast.default_feed, rss_builder.episodes)
          refute_nil podcast.episodes.first.first_rss_published_at
          assert_in_delta podcast.episodes.first.first_rss_published_at, DateTime.now, 15.seconds
        end
      end

      it "makes head requests for first published episodes if 10 or less" do
        episode_1 = create(:episode_with_media, podcast: podcast)
        episode_2 = create(:episode_with_media, podcast: podcast)
        episode_3 = create(:episode_with_media, podcast: podcast)

        stub_head_1 = stub_request(:head, episode_1.enclosure_url)
        stub_head_2 = stub_request(:head, episode_2.enclosure_url)
        stub_head_3 = stub_request(:head, episode_3.enclosure_url)

        job.stub(:s3_client, stub_client) do
          rss_builder = FeedBuilder.new(podcast, podcast.default_feed)
          job.after_publish_rss(podcast, podcast.default_feed, rss_builder.episodes)

          assert_requested(stub_head_1)
          assert_requested(stub_head_2)
          assert_requested(stub_head_3)
        end
      end

      it "does not make head requests if there are more than 10 episodes being published for the first time" do
        mock_eps = Minitest::Mock.new
        mock_eps.expect :count, 11
        mock_eps.expect :update_all, true do |opts|
          assert opts[:first_rss_published_at].is_a?(DateTime)
        end
        mock_eps.expect :first, {enclosure_url: "mock_url"}

        job.stub(:episodes, mock_eps) do
          stub = stub_request(:head, mock_eps.first[:enclosure_url])
          job.update_first_publish_episodes(mock_eps)

          assert_not_requested(stub)
          mock_eps.verify
        end
      end
    end

    describe "validations of the publishing pipeline" do
      it "can process publishing a podcast" do
        job.stub(:s3_client, stub_client) do
          PublishFeedJob.stub(:perform_later, nil) do
            PublishingPipelineState.start_pipeline!(podcast)
          end

          pub_item = PublishingQueueItem.unfinished_items(podcast).first

          rss = job.perform(podcast, pub_item)
          refute_nil rss
          refute_nil job.put_object
          assert_nil job.copy_object

          # it sets the job id on the publishing queue item
          pub_item.reload
          refute_nil pub_item.job_id
          assert_equal pub_item.job_id, job.job_id
        end
      end

      it "will skip the publishing if the pub items are mismatched" do
        job.stub(:s3_client, stub_client) do
          PublishFeedJob.stub(:perform_later, nil) do
            PublishingPipelineState.start_pipeline!(podcast)
          end

          pub_item = PublishingQueueItem.create(podcast: podcast)
          assert job.mismatched_publishing_item?(podcast, pub_item)
          assert_equal :mismatched, job.perform(podcast, pub_item)
        end
      end

      it "will skip the publishing if the pub items are null" do
        job.stub(:s3_client, stub_client) do
          assert PublishingQueueItem.unfinished_items(podcast).empty?

          assert job.null_publishing_item?(podcast, nil)
          assert_equal :null, job.perform(podcast, nil)

          # There is no currently running publishing pipeline
          pub_item = PublishingQueueItem.create(podcast: podcast)
          assert job.null_publishing_item?(podcast, pub_item)

          private_feed.stub(:publish_integration!, true) do
            assert_equal :null, job.perform(podcast, pub_item)
          end

          # `settle_remaining` is called at the end of the publishing job
          # This means pub_item has been picked up and scheduled
          assert_equal "created", pub_item.reload.last_pipeline_state
          PublishingPipelineState.complete!(podcast)
          assert_equal "complete", pub_item.reload.last_pipeline_state

          # Start a pipeline: Create publishing item and transition that item's pipeline to :created
          queue_item = PublishingPipelineState.start_pipeline!(podcast)

          refute job.null_publishing_item?(podcast, queue_item)
          private_feed.stub(:publish_integration!, true) do
            refute_equal :null, job.perform(podcast, queue_item)
          end
        end
      end
    end
  end

  describe "publishing Apple and Megaphone from one feed" do
    let(:podcast) { create(:podcast) }
    let(:mixed_feed) { create(:megaphone_feed, podcast: podcast) }
    let(:apple_config) { create(:delegated_delivery_config, feed: mixed_feed) }
    let(:calls) { [] }

    def publish_mixed_feed(apple_error: nil, megaphone_error: nil)
      apple_config
      mixed_feed.reload
      podcast.stub(:feeds, [mixed_feed]) do
        errors = {apple: apple_error, megaphone: megaphone_error}
        mixed_feed.stub(:publish_integration!, ->(integration) {
          calls << integration
          raise errors[integration] if errors[integration]
        }) do
          job.stub(:publish_rss, ->(*) { calls << :rss }) do
            queue_item = PublishingPipelineState.start_pipeline!(podcast)
            job.perform(podcast, queue_item)
          end
        end
      end
    end

    it "publishes both integrations before RSS with distinct log contexts" do
      logs = capture_json_logs { publish_mixed_feed }

      assert_equal [:apple, :megaphone, :rss], calls
      starts = logs.select { |line| line["msg"] == "Starting integration feed publish" }
      assert_equal ["apple", "megaphone"], starts.map { |line| line["integration"] }
      assert_equal [mixed_feed.id, mixed_feed.id], starts.map { |line| line["feed_id"] }
    end

    it "uses Apple's nonblocking policy even when Megaphone blocks RSS" do
      apple_config.update!(sync_blocks_rss: false)
      assert mixed_feed.megaphone_config.sync_blocks_rss

      publish_mixed_feed(apple_error: Apple::AssetStateTimeoutError.new([]))

      assert_equal [:apple, :megaphone, :rss], calls
      assert PublishingPipelineState.complete?(podcast)
    end

    it "uses Apple's blocking policy even when Megaphone allows RSS" do
      apple_config.update!(sync_blocks_rss: true)
      mixed_feed.megaphone_config.update!(sync_blocks_rss: false)

      publish_mixed_feed(apple_error: Apple::AssetStateTimeoutError.new([]))

      assert_equal [:apple], calls
      assert_equal "retry", PublishingPipelineState.most_recent_state(podcast).status
    end

    it "uses Megaphone's blocking policy even when Apple allows RSS" do
      apple_config.update!(sync_blocks_rss: false)
      mixed_feed.megaphone_config.update!(sync_blocks_rss: true)

      assert_raises(RuntimeError) { publish_mixed_feed(megaphone_error: RuntimeError.new("Megaphone failed")) }

      assert_equal [:apple, :megaphone], calls
    end

    it "publishes Megaphone when Apple is paused" do
      apple_config.update!(publish_enabled: false)

      publish_mixed_feed

      assert_equal [:megaphone, :rss], calls
    end

    it "publishes Apple when Megaphone is paused" do
      apple_config
      mixed_feed.megaphone_config.update!(publish_enabled: false)

      publish_mixed_feed

      assert_equal [:apple, :rss], calls
    end
  end

  describe "publishing to two Apple feeds" do
    let(:podcast) { create(:podcast) }
    let(:key) { create(:apple_key, account_id: podcast.account_id) }
    let(:delivery_feeds) do
      podcast.update!(apple_key: key)
      2.times.map do
        public_feed = create(:public_feed, podcast: podcast)
        binding = create(:apple_show_feed_binding, feed: public_feed)
        delivery_feed = create(:private_feed, podcast: podcast)
        create(:delegated_delivery_config, feed: delivery_feed, key: key, show_feed_binding: binding)
        delivery_feed.reload
      end
    end
    let(:calls) { [] }

    def publish_both_feeds(errors = {})
      actions = delivery_feeds.map do |feed|
        ->(integration) {
          assert_equal :apple, integration
          calls << [:integration, feed.id]
          Rails.logger.info("Publishing test episode")
          raise errors[feed.id] if errors[feed.id]
        }
      end
      capture_json_logs do
        podcast.stub(:feeds, delivery_feeds) do
          delivery_feeds[0].stub(:publish_integration!, actions[0]) do
            delivery_feeds[1].stub(:publish_integration!, actions[1]) do
              job.stub(:publish_rss, ->(_, feed) { calls << [:rss, feed.id] }) do
                queue_item = PublishingPipelineState.start_pipeline!(podcast)
                job.perform(podcast, queue_item)
              end
            end
          end
        end
      end
    end

    it "publishes both feeds before RSS and identifies each publisher's logs" do
      logs = publish_both_feeds

      assert_equal delivery_feeds.map { |feed| [:integration, feed.id] } +
        delivery_feeds.map { |feed| [:rss, feed.id] }, calls
      assert PublishingPipelineState.complete?(podcast)
      starts = logs.select { |line| line["msg"] == "Starting integration feed publish" }
      finishes = logs.select { |line| line["msg"] == "Completed integration feed publish" }
      nested = logs.select { |line| line["msg"] == "Publishing test episode" }
      assert_equal delivery_feeds.map(&:id), starts.map { |line| line["feed_id"] }
      assert_equal delivery_feeds.map(&:id), finishes.map { |line| line["feed_id"] }
      delivery_feeds.each_with_index do |feed, index|
        assert_equal "apple", starts[index]["integration"]
        assert_includes nested[index]["tags"], "integration:apple"
        assert_includes nested[index]["tags"], "feed:#{feed.id}"
        refute_includes nested[index]["tags"], "feed:#{delivery_feeds[1 - index].id}"
      end
      completion = logs.find { |line| line["to_state"] == "complete" }
      refute completion["tags"].any? { |tag| tag.start_with?("feed:", "integration:") }
    end

    it "stops before the second feed and RSS on a blocking timeout" do
      first = delivery_feeds.first
      logs = publish_both_feeds(first.id => Apple::AssetStateTimeoutError.new([]))

      assert_equal [[:integration, first.id]], calls
      assert_equal "retry", PublishingPipelineState.most_recent_state(podcast).status
      timeout = logs.find { |line| line["msg"] == "Apple asset processing timeout" }
      assert_includes timeout["tags"], "feed:#{first.id}"
      refute logs.any? { |line| line["msg"] == "Completed integration feed publish" }
    end

    it "continues to the second feed and RSS after a nonblocking failure" do
      first = delivery_feeds.first
      first.delegated_delivery_config.update!(sync_blocks_rss: false)
      logs = publish_both_feeds(first.id => StandardError.new("Delivery failed"))

      assert_equal delivery_feeds.map { |feed| [:integration, feed.id] } +
        delivery_feeds.map { |feed| [:rss, feed.id] }, calls
      assert PublishingPipelineState.complete?(podcast)
      failure = logs.find { |line| line["msg"] == "Integration feed publish failed" }
      assert_equal first.id, failure["feed_id"]
      assert_equal "apple", failure["integration"]
      assert_includes failure["tags"], "feed:#{first.id}"
      finishes = logs.select { |line| line["msg"] == "Completed integration feed publish" }
      assert_equal [delivery_feeds.last.id], finishes.map { |line| line["feed_id"] }
    end

    it "skips RSS when the second feed requires a retry" do
      second = delivery_feeds.last
      publish_both_feeds(second.id => Apple::AssetStateTimeoutError.new([]))

      assert_equal delivery_feeds.map { |feed| [:integration, feed.id] }, calls
      assert_equal "retry", PublishingPipelineState.most_recent_state(podcast).status
    end
  end

  describe "publishing to apple" do
    let(:podcast) { create(:podcast) }
    let(:public_feed) { podcast.default_feed }
    let(:private_feed) { create(:apple_feed, podcast: podcast) }
    let(:apple_feed) { private_feed }
    let(:delegated_delivery_config) { private_feed.delegated_delivery_config }
    let(:apple_publisher) { delegated_delivery_config.build_publisher }

    before do
      assert private_feed.persisted?
      assert delegated_delivery_config.persisted?
    end

    describe "#perform" do
      it "transitions to the error state upon general apple error" do
        job.stub(:s3_client, stub_client) do
          pqi = PublishingPipelineState.start_pipeline!(podcast)
          # Simulate some method blowing up
          private_feed.stub(:publish_integration!, ->(_) { raise "random apple error" }) do
            podcast.stub(:feeds, [private_feed]) do
              assert_raises(RuntimeError) { job.perform(podcast, pqi) }
              assert_equal ["created", "started", "error_integration", "error"], PublishingPipelineState.where(podcast: podcast).latest_pipelines.order(id: :asc).pluck(:status)
            end
          end
        end
      end
    end

    describe "when the delegated delivery config is present" do
      it "does not schedule publishing to apple if the config is marked as not publishable" do
        apple_feed.delegated_delivery_config.update!(publish_enabled: false)

        private_feed.stub(:publish_integration!, ->(*) { flunk "Published a disabled integration" }) do
          assert_nil job.publish_integration(podcast, apple_feed, :apple)
        end
      end

      it "does run the apple publishing if the config is present and marked as publishable" do
        assert apple_feed.delegated_delivery_config.present?
        assert apple_feed.delegated_delivery_config.publish_enabled
        private_feed.stub(:publish_integration!, :publishing_apple!) do
          assert_equal :publishing_apple!, job.publish_integration(podcast, apple_feed, :apple)
        end
      end

      describe "when the apple publishing fails" do
        before do
          # Simulate a publishing attempt
          PublishingQueueItem.create!(podcast: feed.podcast)
        end

        let(:episode1) { build(:uploaded_apple_episode, show: apple_publisher.show) }
        let(:episode2) { build(:uploaded_apple_episode, show: apple_publisher.show) }
        let(:episodes) { [episode1, episode2] }

        it "logs AssetStateTimeoutError with escalating levels based on duration" do
          assert apple_feed.delegated_delivery_config.present?
          assert apple_feed.delegated_delivery_config.publish_enabled

          # [duration_seconds, expected_log_level_int]
          # Bunyan log levels: 30=info, 40=warn, 50=error
          expected_level_for_durations = [
            [1000, 30],  # info (< 20 min)
            [1200, 40],  # warn (>= 20 min)
            [2099, 40],  # warn (< 35 min)
            [2100, 50]   # error (>= 35 min)
          ]

          expected_level_for_durations.each do |(duration, level)|
            PublishFeedJob.stub(:s3_client, stub_client) do
              episode1.stub(:measure_asset_processing_duration, duration) do
                episode2.stub(:measure_asset_processing_duration, nil) do
                  private_feed.stub(:publish_integration!, ->(_) { raise Apple::AssetStateTimeoutError.new(episodes) }) do
                    podcast.stub(:feeds, [private_feed]) do
                      lines = capture_json_logs do
                        PublishingQueueItem.ensure_queued!(podcast)
                        PublishingPipelineState.attempt!(podcast, perform_later: false)
                      rescue
                        nil
                      end

                      log = lines.find { |l| l["msg"] == "Apple asset processing timeout" }
                      assert log.present?, "Expected log for #{duration}s duration"
                      assert_equal level, log["level"], "Expected level #{level} for #{duration}s duration"

                      assert_equal ["created", "started", "error_integration", "retry"], PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.order(:id).pluck(:status)
                    end
                  end
                end
              end
            end
          end
        end

        it "ends in a terminal retry state if the apple publishing times out" do
          assert apple_feed.delegated_delivery_config.present?
          assert apple_feed.delegated_delivery_config.publish_enabled

          private_feed.stub(:publish_integration!, ->(_) { raise Apple::AssetStateTimeoutError.new([]) }) do
            podcast.stub(:feeds, [private_feed]) do
              PublishingPipelineState.attempt!(feed.podcast, perform_later: false)

              assert_equal ["created", "started", "error_integration", "retry"], PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.order(id: :asc).pluck(:status)
            end
          end
        end

        it "does not raise an error if the apple publishing fails and apple sync does not block rss publishing" do
          stub_request(:get, /#{ENV["PODPING_HOST"]}/).to_return(status: 200)
          assert apple_feed.delegated_delivery_config.present?
          assert apple_feed.delegated_delivery_config.publish_enabled
          apple_feed.delegated_delivery_config.update!(sync_blocks_rss: false)
          feed.reload

          PublishFeedJob.stub(:s3_client, stub_client) do
            private_feed.stub(:publish_integration!, ->(_) { raise "some apple error" }) do
              feed.podcast.stub(:feeds, [podcast.public_feed, private_feed, feed]) do
                # no error raised
                PublishingPipelineState.attempt!(feed.podcast, perform_later: false)
                assert_equal ["created", "started", "error_integration", "published_rss", "published_rss", "published_rss", "complete"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
              end
            end
          end
        end

        it "raises an error and blocks RSS when non-timeout error occurs with sync_blocks_rss enabled" do
          assert apple_feed.delegated_delivery_config.present?
          assert apple_feed.delegated_delivery_config.publish_enabled
          apple_feed.delegated_delivery_config.update!(sync_blocks_rss: true)

          private_feed.stub(:publish_integration!, ->(_) { raise StandardError.new("some apple error") }) do
            podcast.stub(:feeds, [private_feed]) do
              assert_raises(StandardError) { PublishingPipelineState.attempt!(feed.podcast, perform_later: false) }

              assert_equal ["created", "started", "error_integration", "error"], PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.order(id: :asc).pluck(:status)
            end
          end
        end

        it "does not raise when timeout occurs with sync_blocks_rss disabled" do
          stub_request(:get, /#{ENV["PODPING_HOST"]}/).to_return(status: 200)
          assert apple_feed.delegated_delivery_config.present?
          assert apple_feed.delegated_delivery_config.publish_enabled
          apple_feed.delegated_delivery_config.update!(sync_blocks_rss: false)
          feed.reload

          PublishFeedJob.stub(:s3_client, stub_client) do
            private_feed.stub(:publish_integration!, ->(_) { raise Apple::AssetStateTimeoutError.new([]) }) do
              feed.podcast.stub(:feeds, [podcast.public_feed, private_feed, feed]) do
                # no error raised, continues to RSS
                PublishingPipelineState.attempt!(feed.podcast, perform_later: false)
                assert_equal ["created", "started", "error_integration", "published_rss", "published_rss", "published_rss", "complete"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
              end
            end
          end
        end

        it "logs timeout even when sync_blocks_rss is disabled" do
          stub_request(:get, /#{ENV["PODPING_HOST"]}/).to_return(status: 200)
          assert apple_feed.delegated_delivery_config.present?
          assert apple_feed.delegated_delivery_config.publish_enabled
          apple_feed.delegated_delivery_config.update!(sync_blocks_rss: false)
          feed.reload

          PublishFeedJob.stub(:s3_client, stub_client) do
            episode1.stub(:measure_asset_processing_duration, 2000) do
              episode2.stub(:measure_asset_processing_duration, nil) do
                private_feed.stub(:publish_integration!, ->(_) { raise Apple::AssetStateTimeoutError.new(episodes) }) do
                  feed.podcast.stub(:feeds, [podcast.public_feed, private_feed, feed]) do
                    lines = capture_json_logs do
                      PublishingQueueItem.ensure_queued!(podcast)
                      PublishingPipelineState.attempt!(feed.podcast, perform_later: false)
                    end

                    # Should log the error even though sync_blocks_rss is disabled
                    log = lines.find { |l| l["msg"] == "Apple asset processing timeout" }
                    assert log.present?, "AssetStateTimeoutError should be logged even when sync_blocks_rss is disabled"
                    assert_equal [episode1.feeder_id, episode2.feeder_id], log["episode_ids"]
                    assert_equal 2000, log["asset_wait_duration"]

                    # But should still continue to RSS
                    assert_equal ["created", "started", "error_integration", "published_rss", "published_rss", "published_rss", "complete"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
