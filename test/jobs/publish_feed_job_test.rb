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
        rss = job.perform(podcast)
        refute_nil rss
        refute_nil job.put_object
        assert_nil job.copy_object
      end
    end
  end

  describe "publishing to apple" do
    it "does not schedule publishing to apple if there is no apple config" do
      assert_equal [], feed.apple_configs
      assert_equal [], job.publish_apple(feed)
    end

    it "does not schedule publishing to apple if the config is marked as not publishable" do
      apple_config = create(:apple_config, public_feed: feed, publish_enabled: false)
      assert_equal [apple_config], feed.apple_configs.reload
      assert_equal [nil], job.publish_apple(feed)
    end

    it "does schedule publishing if the config is present and marked as publishable" do
      apple_config = create(:apple_config, public_feed: feed, publish_enabled: true)
      assert_equal [apple_config], feed.apple_configs.reload
      assert_equal [PublishAppleJob], job.publish_apple(feed).map(&:class)
    end

    it "performs the job immediately if the config is marked as publishable and syncs rss" do
      apple_config = create(:apple_config, public_feed: feed, publish_enabled: true, sync_blocks_rss: true)
      assert_equal [apple_config], feed.apple_configs.reload

      PublishAppleJob.stub(:perform_now, :now) do
        PublishAppleJob.stub(:perform_later, :later) do
          assert_equal [:now], job.publish_apple(feed)

          apple_config.update!(sync_blocks_rss: false)
          assert_equal [:later], job.publish_apple(feed.reload)
        end
      end
    end
  end
end
