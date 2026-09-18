require "test_helper"

class TestHelper
  include EpisodesHelper
end

describe EpisodesHelper do
  let(:helper) { TestHelper.new }
  let(:podcast) { create(:podcast) }

  describe "#episode_integration_placeholder_status" do
    it "returns 'draft' for draft episodes" do
      draft_episode = create(:episode, podcast: podcast, published_at: nil)
      assert_equal "draft", helper.episode_integration_placeholder_status(draft_episode)
    end

    it "returns 'not_publishable' for published episodes" do
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      assert_equal "not_publishable", helper.episode_integration_placeholder_status(episode)
    end
  end

  describe "#episode_integration_statuses" do
    it "is empty when no feed delivers the episode" do
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)

      assert_empty helper.episode_integration_statuses(episode, :apple)
      assert_empty helper.episode_integration_statuses(episode, :megaphone)
    end

    describe "with apple feed" do
      let(:apple_feed) { create(:apple_feed, podcast: podcast, apple_show_id: "show-1") }
      let(:episode) { create(:episode, podcast: podcast, published_at: 1.hour.ago) }
      let(:draft_episode) { create(:episode_with_media, podcast: podcast, published_at: nil) }
      let(:scheduled_episode) { create(:episode_with_media, podcast: podcast, published_at: 1.hour.from_now) }
      let(:scheduled_episode_without_media) { create(:episode, podcast: podcast, published_at: 1.hour.from_now) }

      before { apple_feed }

      it "returns 'new' when episode has no delivery status yet" do
        assert_equal({apple_feed => "new"}, helper.episode_integration_statuses(episode, :apple))
      end

      describe "with a second Apple feed" do
        let(:other_feed) { create(:private_feed, podcast: podcast) }
        let(:other_config) do
          public_feed = create(:public_feed, podcast: podcast)
          binding = create(:apple_show_feed_binding, feed: public_feed, apple_show_id: "show-2")
          create(:delegated_delivery_config, feed: other_feed, key: podcast.apple_key,
            show_feed_binding: binding, publish_enabled: true)
        end

        before { other_config }

        it "shows the delivery status of the only feed the episode belongs to" do
          episode.feeds = [apple_feed]
          create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-1", uploaded: true, delivered: true)

          assert_equal({apple_feed => "complete"}, helper.episode_integration_statuses(episode, :apple))
        end

        it "shows the delivery status of the second feed when the episode belongs only to it" do
          episode.feeds = [other_feed]
          create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-2", uploaded: true, delivered: false)

          assert_equal({other_feed => "processing"}, helper.episode_integration_statuses(episode, :apple))
        end

        it "returns each feed's delivery status when the episode belongs to both" do
          create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-1", uploaded: true, delivered: true)
          create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-2", uploaded: true, delivered: false)

          assert_nil episode.integration_feed(:apple)
          assert_equal({apple_feed => "complete", other_feed => "processing"}, helper.episode_integration_statuses(episode, :apple))
        end

        it "omits paused feeds from delivery statuses" do
          other_config.update!(publish_enabled: false)
          create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-1", uploaded: true, delivered: true)

          assert_equal apple_feed, episode.integration_feed(:apple)
          assert_equal({apple_feed => "complete"}, helper.episode_integration_statuses(episode, :apple))

          episode.feeds = [other_feed]
          assert_empty helper.episode_integration_statuses(episode, :apple)
        end

        it "reads last updated from the given feed's show" do
          first = create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-1", created_at: 4.hours.ago)
          second = create(:apple_episode_delivery_status, episode: episode, apple_show_id: "show-2", created_at: 2.hours.ago)

          assert_equal first.created_at, helper.episode_integration_updated_at(episode, :apple, apple_feed)
          assert_equal second.created_at, helper.episode_integration_updated_at(episode, :apple, other_feed)
        end

        it "names the feed regardless of how many feeds the episode has" do
          assert_equal "Apple (#{apple_feed.label})", helper.episode_integration_label("Apple", apple_feed)
        end
      end

      it "returns 'disconnected' when the integration facade is unavailable" do
        feed = episode.integration_feeds(:apple).first

        feed.stub(:integration_episode, nil) do
          assert_equal({feed => "disconnected"}, helper.episode_integration_statuses(episode, :apple))
        end
      end

      it "returns 'disconnected' when the integration has no delivery status" do
        integration_episode = Object.new
        integration_episode.define_singleton_method(:delivery_status) { |*| nil }
        feed = episode.integration_feeds(:apple).first

        feed.stub(:integration_episode, integration_episode) do
          assert_equal({feed => "disconnected"}, helper.episode_integration_statuses(episode, :apple))
        end
      end

      it "returns 'incomplete' when episode has delivery status but not uploaded" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: false, delivered: false)
        assert_equal({apple_feed => "incomplete"}, helper.episode_integration_statuses(episode, :apple))
      end

      it "returns 'processing' when episode is uploaded but not delivered" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: false)
        assert_equal({apple_feed => "processing"}, helper.episode_integration_statuses(episode, :apple))
      end

      it "returns 'error' when apple episode has audio asset state error" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: false)
        api_response = build(:apple_episode_api_response,
          item_guid: episode.item_guid,
          apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_FAILURE)
        build(:apple_episode, feeder_episode: episode, api_response: api_response)

        assert_equal({apple_feed => "error"}, helper.episode_integration_statuses(episode, :apple))
      end

      it "returns 'complete' when episode is delivered" do
        create(:apple_episode_delivery_status, episode: episode, uploaded: true, delivered: true)
        assert_equal({apple_feed => "complete"}, helper.episode_integration_statuses(episode, :apple))
      end

      it "returns 'new' when draft episode has no delivery status yet" do
        assert_equal({apple_feed => "new"}, helper.episode_integration_statuses(draft_episode, :apple))
      end

      it "returns 'incomplete' when draft episode has delivery status but not uploaded" do
        create(:apple_episode_delivery_status, episode: draft_episode, uploaded: false, delivered: false)
        assert_equal({apple_feed => "incomplete"}, helper.episode_integration_statuses(draft_episode, :apple))
      end

      it "returns 'uploaded' when draft episode is uploaded but not delivered" do
        create(:apple_episode_delivery_status, episode: draft_episode, uploaded: true, delivered: false)
        assert_equal({apple_feed => "uploaded"}, helper.episode_integration_statuses(draft_episode, :apple))
      end

      it "returns 'error' when draft apple episode has audio asset state error" do
        create(:apple_episode_delivery_status, episode: draft_episode, uploaded: true, delivered: false)
        api_response = build(:apple_episode_api_response,
          item_guid: draft_episode.item_guid,
          apple_hosted_audio_state: Apple::Episode::AUDIO_ASSET_FAILURE)
        build(:apple_episode, feeder_episode: draft_episode, api_response: api_response)

        assert_equal({apple_feed => "error"}, helper.episode_integration_statuses(draft_episode, :apple))
      end

      it "returns 'new' when scheduled episode has no delivery status yet" do
        assert_equal({apple_feed => "new"}, helper.episode_integration_statuses(scheduled_episode, :apple))
      end

      it "returns 'uploaded' when scheduled episode is uploaded but not delivered" do
        create(:apple_episode_delivery_status, episode: scheduled_episode, uploaded: true, delivered: false)
        assert_equal({apple_feed => "uploaded"}, helper.episode_integration_statuses(scheduled_episode, :apple))
      end

      it "shows uploaded during a delayed release and processing when the delay expires" do
        freeze_time do
          apple_feed.update!(episode_offset_seconds: 1.day.to_i)
          draft_episode.update!(published_at: 1.hour.ago)
          create(:apple_episode_delivery_status, episode: draft_episode, uploaded: true, delivered: false)

          assert_equal({apple_feed => "uploaded"}, helper.episode_integration_statuses(draft_episode, :apple))

          travel 23.hours
          assert_equal({apple_feed => "processing"}, helper.episode_integration_statuses(draft_episode, :apple))
        end
      end

      it "is empty with a 'not_publishable' placeholder when scheduled episode has no uploadable media" do
        assert_empty helper.episode_integration_statuses(scheduled_episode_without_media, :apple)
        assert_equal "not_publishable", helper.episode_integration_placeholder_status(scheduled_episode_without_media)
      end

      it "is empty with a 'draft' placeholder when draft episode has no uploadable media" do
        draft_episode_without_media = create(:episode, podcast: podcast, published_at: nil)

        assert_empty helper.episode_integration_statuses(draft_episode_without_media, :apple)
        assert_equal "draft", helper.episode_integration_placeholder_status(draft_episode_without_media)
      end
    end

    it "shows separate statuses and timestamps for Apple and Megaphone on the same feed" do
      mixed_feed = create(:megaphone_feed, podcast: podcast)
      config = create(:delegated_delivery_config, feed: mixed_feed)
      episode = create(:episode, podcast: podcast, published_at: 1.hour.ago)
      apple_status = create(:apple_episode_delivery_status, episode: episode,
        apple_show_id: config.apple_show_id, uploaded: true, delivered: true, created_at: 2.hours.ago)
      megaphone_status = create(:megaphone_episode_delivery_status, episode: episode,
        uploaded: false, delivered: false, created_at: 1.hour.ago)

      assert_equal({mixed_feed => "complete"}, helper.episode_integration_statuses(episode, :apple))
      assert_equal({mixed_feed => "incomplete"}, helper.episode_integration_statuses(episode, :megaphone))
      assert_equal apple_status.created_at, helper.episode_integration_updated_at(episode, :apple, mixed_feed)
      assert_equal megaphone_status.created_at, helper.episode_integration_updated_at(episode, :megaphone, mixed_feed)
    end

    describe "with megaphone feed" do
      let(:megaphone_feed) { create(:megaphone_feed, podcast: podcast) }
      let(:episode) { create(:episode, podcast: podcast, published_at: 1.hour.ago) }

      before { megaphone_feed }

      it "returns 'new' when episode has no delivery status yet" do
        assert_equal({megaphone_feed => "new"}, helper.episode_integration_statuses(episode, :megaphone))
      end

      it "is empty for draft episodes since megaphone does not upload drafts" do
        draft_episode = create(:episode_with_media, podcast: podcast, published_at: nil)

        assert_empty helper.episode_integration_statuses(draft_episode, :megaphone)
        assert_equal "draft", helper.episode_integration_placeholder_status(draft_episode)
      end
    end
  end

  describe "#episode_integration_updated_at" do
    let(:episode) { create(:episode, podcast: podcast, updated_at: 1.day.ago) }
    let(:apple_feed) { create(:apple_feed, podcast: podcast, apple_show_id: "show-1") }
    let(:megaphone_feed) { create(:megaphone_feed, podcast: podcast) }

    it "returns episode updated_at when no sync logs or delivery status exist" do
      assert_equal episode.updated_at, helper.episode_integration_updated_at(episode, :megaphone, megaphone_feed)
    end

    it "returns episode updated_at when the integration facade is unavailable" do
      apple_feed.stub(:integration_episode, nil) do
        assert_equal episode.updated_at, helper.episode_integration_updated_at(episode, :apple, apple_feed)
      end
    end

    it "returns apple_sync_log updated_at for apple integration" do
      sync_log = SyncLog.create!(
        integration: :apple,
        feeder_type: :episodes,
        feeder_id: episode.id,
        external_id: "123",
        external_show_id: "show-1",
        api_response: {},
        updated_at: 2.hours.ago
      )

      assert_equal sync_log.updated_at, helper.episode_integration_updated_at(episode, :apple, apple_feed)
    end

    it "returns sync_log updated_at for non-apple integrations" do
      sync_log = SyncLog.create!(feeder_id: episode.id, feeder_type: :episodes, external_id: "456",
        api_response: {}, integration: :megaphone, updated_at: 3.hours.ago)

      assert_equal sync_log.updated_at, helper.episode_integration_updated_at(episode, :megaphone, megaphone_feed)
    end

    it "returns delivery status created_at for apple integration" do
      delivery_status = create(:apple_episode_delivery_status, episode: episode, created_at: 4.hours.ago)

      assert_equal delivery_status.created_at, helper.episode_integration_updated_at(episode, :apple, apple_feed)
    end

    it "returns delivery status created_at for non-apple integrations" do
      delivery_status = create(:megaphone_episode_delivery_status, episode: episode, created_at: 5.hours.ago)

      assert_equal delivery_status.created_at, helper.episode_integration_updated_at(episode, :megaphone, megaphone_feed)
    end
  end
end
