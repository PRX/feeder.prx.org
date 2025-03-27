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

    describe "the first time an episode is published to the rss" do
      it "records the timestamp when the episode is published to rss" do
        create(:episode, podcast: podcast)
        assert_nil podcast.episodes.second.first_rss_published_at

        job.stub(:s3_client, stub_client) do
          job.save_file(podcast, podcast.default_feed)
          refute_nil podcast.episodes.second.first_rss_published_at
          assert_in_delta podcast.episodes.second.first_rss_published_at, DateTime.now, 15.seconds
        end
      end

      it "only records a timestamp if it's published to the default feed" do
        create(:episode, podcast: podcast)
        assert_nil podcast.episodes.second.first_rss_published_at

        job.stub(:s3_client, stub_client) do
          job.save_file(podcast, feed)
          assert_nil podcast.episodes.second.first_rss_published_at
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

  describe "publishing to apple" do
    let(:podcast) { create(:podcast) }
    let(:public_feed) { podcast.default_feed }
    let(:private_feed) { create(:apple_feed, podcast: podcast) }
    let(:apple_feed) { private_feed }
    let(:apple_config) { private_feed.apple_config }
    let(:apple_publisher) { apple_config.build_publisher }

    before do
      assert private_feed.persisted?
      assert apple_config.persisted?
    end

    describe "#perform" do
      it "transitions to the error state upon general apple error" do
        job.stub(:s3_client, stub_client) do
          pqi = PublishingPipelineState.start_pipeline!(podcast)
          # Simulate some method blowing up
          private_feed.stub(:publish_integration!, -> { raise "random apple error" }) do
            podcast.stub(:feeds, [private_feed]) do
              assert_raises(RuntimeError) { job.perform(podcast, pqi) }
              assert_equal ["created", "started", "error_integration", "error"], PublishingPipelineState.where(podcast: podcast).latest_pipelines.order(id: :asc).pluck(:status)
            end
          end
        end
      end
    end

    it "does not schedule publishing to apple if the apple config prevents it" do
      apple_feed.apple_config.update!(publish_enabled: false)
      assert_nil job.publish_integration(podcast, apple_feed)
    end

    it "does not schedule publishing to apple if the apple config is disabled" do
      apple_feed.apple_config.update!(publish_enabled: false)
      assert_nil job.publish_integration(podcast, apple_feed)
    end

    describe "when the apple config is present" do
      it "does not schedule publishing to apple if the config is marked as not publishable" do
        apple_feed.apple_config.update!(publish_enabled: false)

        assert_nil job.publish_integration(podcast, apple_feed)
      end

      it "does run the apple publishing if the config is present and marked as publishable" do
        assert apple_feed.apple_config.present?
        assert apple_feed.apple_config.publish_enabled
        private_feed.stub(:publish_integration!, :publishing_apple!) do
          assert_equal :publishing_apple!, job.publish_integration(podcast, apple_feed)
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

        it "logs message if the apple publishing times out" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled

          expected_level_for_timeouts = [
            [0, 40],
            [1, 40],
            [2, 40],
            [3, 40],
            [4, 40],
            [5, 50],
            [6, 60]
          ]

          expected_level_for_timeouts.each do |(attempts, level)|
            # simulate a episode waiting n times
            episodes.first.apple_episode_delivery_status.update(asset_processing_attempts: attempts)

            PublishFeedJob.stub(:s3_client, stub_client) do
              private_feed.stub(:publish_integration!, -> { raise Apple::AssetStateTimeoutError.new(episodes) }) do
                podcast.stub(:feeds, [private_feed]) do
                  lines = capture_json_logs do
                    PublishingQueueItem.ensure_queued!(podcast)
                    PublishingPipelineState.attempt!(podcast, perform_later: false)
                  rescue
                    nil
                  end

                  log = lines.find { |l| l["msg"].include?("Timeout waiting for asset state change") }
                  assert log.present?
                  assert_equal level, log["level"]

                  assert_equal ["created", "started", "error_integration", "retry"], PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.order(:id).pluck(:status)
                end
              end
            end
          end
        end

        it "raises an error if the apple publishing times out" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled

          private_feed.stub(:publish_integration!, -> { raise Apple::AssetStateTimeoutError.new([]) }) do
            podcast.stub(:feeds, [private_feed]) do
              assert_raises(Apple::AssetStateTimeoutError) { PublishingPipelineState.attempt!(feed.podcast, perform_later: false) }

              assert_equal ["created", "started", "error_integration", "retry"], PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.order(id: :asc).pluck(:status)
            end
          end
        end

        it "raises an error if the apple publishing times out" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled

          private_feed.stub(:publish_integration!, -> { raise Apple::AssetStateTimeoutError.new([]) }) do
            podcast.stub(:feeds, [private_feed]) do
              assert_raises(Apple::AssetStateTimeoutError) { PublishingPipelineState.attempt!(feed.podcast, perform_later: false) }

              assert_equal ["created", "started", "error_integration", "retry"], PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.order(id: :asc).pluck(:status)
            end
          end
        end

        it "does not raise an error if the apple publishing fails and apple sync does not block rss publishing" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled
          apple_feed.apple_config.update!(sync_blocks_rss: false)
          feed.reload

          PublishFeedJob.stub(:s3_client, stub_client) do
            private_feed.stub(:publish_integration!, -> { raise "some apple error" }) do
              feed.podcast.stub(:feeds, [podcast.public_feed, private_feed, feed]) do
                # no error raised
                PublishingPipelineState.attempt!(feed.podcast, perform_later: false)
                assert_equal ["created", "started", "error_integration", "published_rss", "published_rss", "published_rss", "complete"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
              end
            end
          end
        end
      end
    end
  end
end
