require "test_helper"

describe PublishFeedJob do
  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }
  let(:feed) { create(:feed, podcast: podcast, slug: "adfree") }

  let(:job) { PublishFeedJob.new }

  it "knows the right bucket to write to" do
    assert_equal job.feeder_storage_bucket, "test-prx-feed"
    ENV["FEEDER_STORAGE_BUCKET"] = "foo"
    assert_equal job.feeder_storage_bucket, "foo"
    ENV["FEEDER_STORAGE_BUCKET"] = "test-prx-feed"
  end

  it "knows the right key to write to" do
    assert_equal job.key(podcast, podcast.default_feed), "#{podcast.path}/feed-rss.xml"
    assert_equal job.key(podcast, feed), "#{podcast.path}/adfree/feed-rss.xml"
  end

  describe "saving the rss file" do
    let(:stub_client) { Aws::S3::Client.new(stub_responses: true) }

    it "can save a podcast file" do
      job.stub(:client, stub_client) do
        refute_nil job.save_file(podcast, podcast.default_feed)
        refute_nil job.save_file(podcast, feed)
      end
    end

    it "can process publishing a podcast" do
      job.stub(:client, stub_client) do
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
      job.stub(:client, stub_client) do
        PublishFeedJob.stub(:perform_later, nil) do
          PublishingPipelineState.start_pipeline!(podcast)
        end

        pub_item = PublishingQueueItem.create(podcast: podcast)
        assert_equal :mismatched, job.perform(podcast, pub_item)
      end
    end
  end

  describe "publishing to apple" do
    it "does not schedule publishing to apple if there is no apple config" do
      assert_equal [], feed.apple_configs
      assert_equal [], job.publish_apple(feed)
    end

    describe "when the apple config is present" do
      let(:apple_config) { create(:apple_config, public_feed: feed) }

      it "does not schedule publishing to apple if the config is marked as not publishable" do
        apple_config.update!(publish_enabled: false)
        assert_equal [apple_config], feed.apple_configs.reload
        assert_equal [nil], job.publish_apple(feed)
      end

      it "does run the apple publishing if the config is present and marked as publishable" do
        assert_equal [apple_config], feed.apple_configs.reload
        PublishAppleJob.stub(:perform_now, :publishing_apple!) do
          assert_equal [:publishing_apple!], job.publish_apple(feed)
        end
      end

      it "Performs the apple publishing job based regardless of sync_blocks_rss flag" do
        assert_equal [apple_config], feed.apple_configs.reload

        # stub the two possible ways the job can be called
        # perform_later is not used.
        PublishAppleJob.stub(:perform_later, :perform_later) do
          PublishAppleJob.stub(:perform_now, :perform_now) do
            apple_config.update!(sync_blocks_rss: true)

            assert_equal [:perform_now], job.publish_apple(feed)

            apple_config.update!(sync_blocks_rss: false)
            feed.reload
            assert_equal [:perform_now], job.publish_apple(feed)
          end
        end
      end

      describe "when the apple publishing fails" do
        before do
          # Simulate a publishing attempt
          PublishingQueueItem.create!(podcast: feed.podcast)
          PublishingPipelineState.attempt!(feed.podcast)
          PublishingPipelineState.start!(feed.podcast)
        end
        it "raises an error if the apple publishing fails" do
          assert_equal [apple_config], feed.apple_configs.reload

          PublishAppleJob.stub(:perform_now, ->(*, **) { raise "some apple error" }) do
            # it raises
            assert_raises(RuntimeError) { job.publish_apple(feed) }

            assert_equal ["created", "started", "error_apple"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort
          end
        end

        it "does not raise an error if the apple publishing is not blocking RSS" do
          assert_equal [apple_config], feed.apple_configs.reload
          feed.apple_configs.first.update!(sync_blocks_rss: false)

          mock = Minitest::Mock.new
          mock.expect(:call, nil, [RuntimeError])

          PublishAppleJob.stub(:perform_now, ->(*, **) { raise "some apple error" }) do
            NewRelic::Agent.stub(:notice_error, mock) do
              job.publish_apple(feed)
            end
          end
          assert_equal ["created", "started", "error_apple"].sort, PublishingPipelineState.where(podcast: feed.podcast).latest_pipelines.pluck(:status).sort

          mock.verify
        end
      end
    end
  end
end
