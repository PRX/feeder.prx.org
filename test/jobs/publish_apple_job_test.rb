require "test_helper"

describe PublishAppleJob do
  let(:episode) { create(:episode, prx_uri: "/api/v1/stories/87683") }
  let(:podcast) { episode.podcast }
  let(:feed) { podcast.default_feed }
  let(:apple_feed) { create(:apple_feed, podcast: podcast) }

  describe "publishing to apple" do
    it "does not publish to apple unless publish_enabled?" do
      apple_feed.apple_config.update(publish_enabled: false)

      # test that the `publish_to_apple` method is not called
      PublishAppleJob.stub(:publish_to_apple, ->(x) { raise "should not be called" }) do
        assert_nil PublishAppleJob.perform_now(apple_feed.apple_config)
      end
    end

    it "does publish to apple if publish_enabled?" do
      apple_feed.apple_config.update(publish_enabled: true)

      PublishAppleJob.stub(:publish_to_apple, :it_published!) do
        assert_equal :it_published!, PublishAppleJob.perform_now(apple_feed.apple_config)
      end
    end
  end
end
