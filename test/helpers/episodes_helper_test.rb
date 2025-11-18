require "test_helper"

class TestHelper
  include EpisodesHelper
end

describe EpisodesHelper do
  let(:helper) { TestHelper.new }
  let(:podcast) { create(:podcast) }

  describe "#episode_integration_status" do
    it "returns 'not_publishable' when episode does not publish to the integration" do
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      assert_equal "not_publishable", helper.episode_integration_status(:apple, episode)
      assert_equal "not_publishable", helper.episode_integration_status(:megaphone, episode)
    end

    describe "with apple feed" do
      let(:apple_feed) { create(:apple_feed, podcast: podcast) }
      let(:episode) { create(:episode, podcast: podcast, published_at: 1.hour.ago) }

      before { apple_feed }

      it "returns 'new' when episode has no delivery status yet" do
        assert_equal "new", helper.episode_integration_status(:apple, episode)
      end

      it "returns 'incomplete' when episode has delivery status but not uploaded" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: false, delivered: false)
        assert_equal "incomplete", helper.episode_integration_status(:apple, episode)
      end

      it "returns 'processing' when episode is uploaded but not delivered" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: false)
        assert_equal "processing", helper.episode_integration_status(:apple, episode)
      end

      it "returns 'error' when apple episode has audio asset state error" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: false)
        api_response = build(:apple_episode_api_response,
          item_guid: episode.item_guid,
          apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_FAILURE)
        create(:apple_episode, feeder_episode: episode, api_response: api_response)

        assert_equal "error", helper.episode_integration_status(:apple, episode)
      end

      it "returns 'complete' when episode is delivered" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: true)
        assert_equal "complete", helper.episode_integration_status(:apple, episode)
      end
    end

    describe "with megaphone feed" do
      let(:megaphone_feed) { create(:megaphone_feed, podcast: podcast) }
      let(:episode) { create(:episode, podcast: podcast, published_at: 1.hour.ago) }

      before { megaphone_feed }

      it "returns 'new' when episode has no delivery status yet" do
        assert_equal "new", helper.episode_integration_status(:megaphone, episode)
      end
    end
  end
end
