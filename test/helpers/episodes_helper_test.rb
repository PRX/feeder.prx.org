require "test_helper"

class TestHelper
  include EpisodesHelper
end

describe EpisodesHelper do
  let(:helper) { TestHelper.new }
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  describe "#episode_integration_status" do
    it "returns 'not_publishable' when episode does not publish to the integration" do
      # No integration feed exists, so publish_to_integration? returns false
      assert_equal "not_publishable", helper.episode_integration_status(:apple, episode)
      assert_equal "not_publishable", helper.episode_integration_status(:megaphone, episode)
    end

    it "returns 'new' when episode publishes to integration but has no delivery status yet" do
      apple_feed = create(:apple_feed, podcast: podcast)
      # Make sure the episode is included in the feed
      apple_feed.reload

      # Mock the publish_to_integration? to return true
      episode.stub :publish_to_integration?, true do
        assert_equal "new", helper.episode_integration_status(:apple, episode)
      end
    end

    it "returns 'incomplete' when episode has delivery status but not uploaded" do
      apple_feed = create(:apple_feed, podcast: podcast)
      delivery_status = create(:apple_episode_delivery_status, episode: episode, uploaded: false, delivered: false)

      assert_equal "incomplete", helper.episode_integration_status(:apple, episode)
    end

    it "returns 'processing' when episode is uploaded but not delivered" do
      apple_feed = create(:apple_feed, podcast: podcast)
      delivery_status = create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: false)

      assert_equal "processing", helper.episode_integration_status(:apple, episode)
    end

    it "returns 'complete' when episode is delivered" do
      apple_feed = create(:apple_feed, podcast: podcast)
      delivery_status = create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: true)

      assert_equal "complete", helper.episode_integration_status(:apple, episode)
    end

    it "works for megaphone integration" do
      megaphone_feed = create(:megaphone_feed, podcast: podcast)

      # Mock the publish_to_integration? to return true for megaphone
      episode.stub :publish_to_integration?, true do
        assert_equal "new", helper.episode_integration_status(:megaphone, episode)
      end
    end
  end
end
