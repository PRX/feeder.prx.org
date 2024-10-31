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

    it "transitions to the error state upon rss error" do
      PublishingPipelineState.start_pipeline!(podcast)
      assert_raises(RuntimeError) { job.handle_rss_error(podcast, feed, RuntimeError.new("rss error")) }
      assert_equal ["created", "error_rss"], PublishingPipelineState.where(podcast: podcast).latest_pipelines.order(id: :asc).pluck(:status)
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

          PublishAppleJob.stub(:do_perform, :publishing_apple!) do
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
          PublishAppleJob.stub(:do_perform, :publishing_apple!) do
            refute_equal :null, job.perform(podcast, queue_item)
          end
        end
      end
    end
  end

  describe "publishing to apple" do
    let(:apple_feed) { private_feed }
    let(:apple_config) { podcast.apple_config }

    before do
      assert private_feed.persisted?
      assert podcast.reload.apple_config.present?
    end

    describe "#perform" do
      it "transitions to the error state upon general apple error" do
        job.stub(:s3_client, stub_client) do
          pqi = PublishingPipelineState.start_pipeline!(podcast)
          # Simulate some method blowing up
          PublishAppleJob.stub(:do_perform, ->(*, **) { raise "some apple error" }) do
            assert_raises(RuntimeError) { job.perform(podcast, pqi) }
            assert_equal ["created", "started", "error_apple", "error"], PublishingPipelineState.where(podcast: podcast).latest_pipelines.order(id: :asc).pluck(:status)
          end
        end
      end
    end

    it "transitions to the apple_error state upon general apple error" do
      PublishingPipelineState.start_pipeline!(podcast)
      assert_raises(RuntimeError) { job.handle_apple_error(podcast, RuntimeError.new("apple error")) }
      assert_equal ["created", "error_apple"], PublishingPipelineState.where(podcast: podcast).latest_pipelines.pluck(:status)
    end

    it "does not schedule publishing to apple if the apple config prevents it" do
      podcast.apple_config.update!(publish_enabled: false)
      assert_nil job.publish_apple(podcast, apple_feed)
    end

    it "does not schedule publishing to apple if the apple config is disabled" do
      apple_config.update!(publish_enabled: false)
      assert_nil job.publish_apple(podcast, apple_feed)
    end

    describe "when the apple config is present" do
      it "does not schedule publishing to apple if the config is marked as not publishable" do
        podcast.apple_config.update!(publish_enabled: false)

        assert_nil job.publish_apple(podcast, apple_feed)
      end

      it "does run the apple publishing if the config is present and marked as publishable" do
        assert apple_feed.apple_config.present?
        assert apple_feed.apple_config.publish_enabled
        PublishAppleJob.stub(:do_perform, :publishing_apple!) do
          assert_equal :publishing_apple!, job.publish_apple(podcast, apple_feed)
        end
      end

      describe "when the apple publishing fails" do
        before do
          # Simulate a publishing attempt
          PublishingQueueItem.create!(podcast: feed.podcast)
        end

        it "raises an error if the apple publishing fails" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled

          PublishAppleJob.stub(:do_perform, ->(*, **) { raise "some apple error" }) do
            assert_raises(RuntimeError) { PublishingPipelineState.attempt!(feed.podcast, perform_later: false) }

            assert_equal ["created", "started", "error", "error_apple"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
          end
        end

        it "does not raise an error if the apple publishing fails and apple sync does not block rss publishing" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled
          apple_feed.apple_config.update!(sync_blocks_rss: false)
          feed.reload

          PublishFeedJob.stub(:s3_client, stub_client) do
            PublishAppleJob.stub(:do_perform, ->(*, **) { raise "some apple error" }) do
              # no error raised
              PublishingPipelineState.attempt!(feed.podcast, perform_later: false)

              assert_equal ["created", "started", "error_apple", "published_rss", "published_rss", "published_rss", "complete"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
            end
          end
        end

        it "raises an error if the apple publishing times out" do
          assert apple_feed.apple_config.present?
          assert apple_feed.apple_config.publish_enabled

          PublishAppleJob.stub(:do_perform, ->(*, **) { raise Apple::AssetStateTimeoutError.new([]) }) do
            assert_raises(Apple::AssetStateTimeoutError) { PublishingPipelineState.attempt!(feed.podcast, perform_later: false) }

            assert_equal ["created", "started", "error", "error_apple"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
          end
        end
      end
    end
  end
end
