require "test_helper"

class TestHelper
  include EpisodesHelper
end

describe EpisodesHelper do
  let(:helper) { TestHelper.new }
  let(:podcast) { create(:podcast) }

  describe "#episode_integration_status" do
    it "returns 'draft' when episode is a draft" do
      draft_episode = create(:episode, podcast: podcast, published_at: nil)
      assert_equal "draft", helper.episode_integration_status(:apple, draft_episode)
      assert_equal "draft", helper.episode_integration_status(:megaphone, draft_episode)
    end

    it "returns 'not_publishable' when episode does not publish to the integration" do
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      assert_equal "not_publishable", helper.episode_integration_status(:apple, episode)
      assert_equal "not_publishable", helper.episode_integration_status(:megaphone, episode)
    end

    describe "with apple feed" do
      let(:apple_feed) { create(:apple_feed, podcast: podcast, apple_show_id: "show-1") }
      let(:episode) { create(:episode, podcast: podcast, published_at: 1.hour.ago) }

      before { apple_feed }

      it "returns 'new' when episode has no delivery status yet" do
        assert_equal "new", helper.episode_integration_status(:apple, episode)
      end

      it "returns 'disconnected' when the integration facade is unavailable" do
        episode.stub(:integration_episode, nil) do
          assert_equal "disconnected", helper.episode_integration_status(:apple, episode)
        end
      end

      it "returns 'disconnected' when the integration has no delivery status" do
        integration_episode = Object.new
        integration_episode.define_singleton_method(:delivery_status) { |*| nil }

        episode.stub(:integration_episode, integration_episode) do
          assert_equal "disconnected", helper.episode_integration_status(:apple, episode)
        end
      end

      it "returns 'disconnected' when the integration facade has no show identity" do
        integration_episode = Object.new
        integration_episode.define_singleton_method(:delivery_status) do |*|
          raise Apple::MissingShowIdentityError, "missing show"
        end

        episode.stub(:integration_episode, integration_episode) do
          assert_equal "disconnected", helper.episode_integration_status(:apple, episode)
        end
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
        build(:apple_episode, feeder_episode: episode, api_response: api_response)

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

  describe "#episode_integration_updated_at" do
    let(:episode) { create(:episode, podcast: podcast, updated_at: 1.day.ago) }

    it "returns episode updated_at when no sync logs or delivery status exist" do
      assert_equal episode.updated_at, helper.episode_integration_updated_at(:megaphone, episode)
    end

    it "returns episode updated_at when the integration facade is unavailable" do
      episode.stub(:integration_episode, nil) do
        assert_equal episode.updated_at, helper.episode_integration_updated_at(:apple, episode)
      end
    end

    it "returns episode updated_at when the integration facade has no show identity" do
      integration_episode = Object.new
      integration_episode.define_singleton_method(:sync_log) do
        raise Apple::MissingShowIdentityError, "missing show"
      end

      episode.stub(:integration_episode, integration_episode) do
        assert_equal episode.updated_at, helper.episode_integration_updated_at(:apple, episode)
      end
    end

    it "returns apple_sync_log updated_at for apple integration" do
      create(:apple_feed, podcast: podcast, apple_show_id: "show-1")
      sync_log = SyncLog.create!(
        integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "123",
        apple_show_id: "show-1",
        api_response: {},
        updated_at: 2.hours.ago
      )

      assert_equal sync_log.updated_at, helper.episode_integration_updated_at(:apple, episode)
    end

    it "returns sync_log updated_at for non-apple integrations" do
      sync_log = SyncLog.create!(feeder_id: episode.id, feeder_type: :episodes, external_id: "456",
        api_response: {}, integration: :megaphone, updated_at: 3.hours.ago)
      assert_equal sync_log.updated_at, helper.episode_integration_updated_at(:megaphone, episode)
    end

    it "returns delivery status created_at for apple integration" do
      create(:apple_feed, podcast: podcast, apple_show_id: "show-1")
      delivery_status = create(:apple_episode_delivery_status, episode: episode, created_at: 4.hours.ago)

      assert_equal delivery_status.created_at, helper.episode_integration_updated_at(:apple, episode)
    end

    it "returns delivery status created_at for non-apple integrations" do
      delivery_status = create(:megaphone_episode_delivery_status, episode: episode, created_at: 5.hours.ago)

      assert_equal delivery_status.created_at, helper.episode_integration_updated_at(:megaphone, episode)
    end
  end
end
