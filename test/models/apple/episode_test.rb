# frozen_string_literal: true

require "test_helper"

describe Apple::Episode do
  let(:podcast) { create(:podcast) }

  let(:public_feed) { podcast.default_feed }
  let(:private_feed) { create(:private_feed, podcast: podcast) }

  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }

  let(:episode) { create(:episode, podcast: podcast) }
  let(:apple_show) do
    Apple::Show.new(api: apple_api,
      public_feed: public_feed,
      private_feed: private_feed)
  end
  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }
  let(:apple_episode_api_response) { build(:apple_episode_api_response, apple_episode_id: "123") }
  let(:external_id) { apple_episode_api_response["api_response"]["api_response"]["val"]["data"]["id"] }

  before do
    episode.create_apple_sync_log(external_id: external_id, **apple_episode_api_response)
  end

  describe "#apple_json" do
    let(:apple_episode_list) do
      [
        apple_episode_json
      ]
    end

    it "instantiates with an api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode)

      assert_equal "123", ep.apple_id
      assert_equal "456", ep.audio_asset_vendor_id
      assert_equal true, ep.drafting?, true
      assert_equal episode.item_guid, ep.guid
    end

    it "instantiates with a nil api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode)
      ep.feeder_episode.apple_sync_log.destroy
      ep.feeder_episode.reload

      assert_nil ep.apple_id
      assert_raises(RuntimeError, "incomplete api response") { ep.audio_asset_vendor_id }
      # It does not exists yet, so it is not drafting
      assert_equal false, ep.drafting?
      # Comes from the feeder model
      assert_equal episode.item_guid, ep.guid
    end
  end

  describe "#enclosure_url" do
    it "should add auth query param" do
      assert_match(/auth=/, apple_episode.enclosure_url)
    end
  end

  describe "#waiting_for_asset_state?" do
    let(:container) { create(:apple_podcast_container, episode: episode, apple_episode_id: "123") }

    let(:delivery) do
      pd = Apple::PodcastDelivery.new(episode: episode, podcast_container: container)
      pd.save!
      pd
    end

    let(:delivery_file) do
      pdf = Apple::PodcastDeliveryFile.new(episode: episode, podcast_delivery: delivery)
      pdf.update(apple_sync_log: SyncLog.new(**build(:podcast_delivery_file_api_response).merge(external_id: "123"), feeder_type: :podcast_delivery_files))
      pdf.save!
      pdf
    end

    before do
      assert_equal [delivery_file], apple_episode.podcast_delivery_files
    end

    it "should be true if all the conditions are met" do
      assert_equal true, apple_episode.waiting_for_asset_state?
    end

    it "should be true if there are no podcast delivery files and the asset state is UNSPECIFIED" do
      apple_episode.podcast_container.stub(:podcast_delivery_files, []) do
        assert_equal true, apple_episode.waiting_for_asset_state?
      end
    end

    it "should be false if the delivery file is not delivered" do
      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_delivery_state: "AWAITING_UPLOAD"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end

    it "should be false if the delivery file has asset processing errors" do
      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_processing_state: "VALIDATION_FAILED"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end

    it "should be false if the delivery file has errors" do
      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response, asset_processing_state: "VALIDATION_FAILED"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end

    it "should be false if the episode has a non complete apple hosted audio asset state" do
      apple_episode.api_response["api_response"]["val"]["data"]["attributes"]["appleHostedAudioAssetState"] = Apple::Episode::AUDIO_ASSET_FAILURE

      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response).merge(external_id: "123"))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end
  end

  describe "#episode_update_parameters" do
    it "should mirror the create params with the addition of the id" do
      apple_episode.stub(:apple_id, "123") do
        assert_equal "123", apple_episode.episode_update_parameters[:data][:id]
      end
    end
  end

  describe ".update_episodes" do
    it "ignores 409 errors for some episodes" do
      episode1 = create(:episode, podcast: podcast)
      episode2 = create(:episode, podcast: podcast)
      apple_episode1 = build(:apple_episode, show: apple_show, feeder_episode: episode1)
      apple_episode2 = build(:apple_episode, show: apple_show, feeder_episode: episode2)

      # Mock the bridge_remote_and_retry method to return a mix of successful and 409 error responses
      mock_response = [
        {
          "api_response" => {
            "ok" => true,
            "err" => false,
            "val" => {"data" => {"id" => "123", "type" => "episodes"}}
          },
          "request_metadata" => {"apple_episode_id" => "123", "guid" => episode1.item_guid}
        },
        {
          "api_response" => {
            "ok" => false,
            "err" => true,
            "val" => {"data" => {"status" => "409", "title" => "Conflict"}}
          },
          "request_metadata" => {"apple_episode_id" => "456", "guid" => episode2.item_guid}
        }
      ]

      apple_api.stub :bridge_remote, OpenStruct.new(code: "200", body: mock_response.to_json) do
        apple_episode2.feeder_episode.apple_sync_log.destroy
        apple_episode2.feeder_episode.reload

        updated_episodes = Apple::Episode.update_episodes(apple_api, [apple_episode1, apple_episode2])

        assert_equal 1, updated_episodes.length, "Expected one successfully updated episode"
        assert_equal "123", updated_episodes.first.external_id, "Expected the successful episode to be updated"

        # Verify that the 409 error was ignored and didn't cause the method to raise an error
        apple_episode2.feeder_episode.reload
        assert_nil apple_episode2.feeder_episode.apple_sync_log, "Expected no sync log update for the episode with 409 error"
      end
    end
  end

  describe "#needs_media_version?" do
    let(:audio_version_id) {
    }
    it "should be true if the delivery status is nil or has nil attrs" do
      assert apple_episode.delivery_statuses.destroy_all
      assert apple_episode.delivery_status.source_media_version_id.nil?

      assert_equal true, apple_episode.needs_media_version?
    end

    it "should be true if the delivery status indicates another media version" do
      create(:content, episode: apple_episode.feeder_episode, position: 1, status: "complete")
      create(:content, episode: apple_episode.feeder_episode, position: 2, status: "complete")
      mid = apple_episode.feeder_episode.reload.cut_media_version!

      apple_episode.feeder_episode.apple_update_delivery_status(delivered: true, source_media_version_id: mid.id)
      refute apple_episode.needs_media_version?

      apple_episode.feeder_episode.apple_update_delivery_status(source_media_version_id: -1)

      assert apple_episode.needs_media_version?
    end
  end

  describe "#synced_with_apple?" do
    let(:apple_episode_api_response) { build(:apple_episode_api_response, publishing_state: "PUBLISH") }

    it "should be false when drafting" do
      ep = build(:uploaded_apple_episode)
      assert_equal true, ep.synced_with_apple?

      ep.stub(:drafting?, true) do
        assert_equal false, ep.synced_with_apple?
      end
    end

    it "should be false when the podcast_container is nil" do
      ep = build(:apple_episode)
      assert ep.podcast_container.nil?

      # it returns early via the guard
      ep.stub(:podcast_container, -> { raise "shouldn't happen" }) do
        ep.stub(:has_container?, false) do
          refute ep.container_upload_complete?
        end
      end
    end
  end

  describe "#enclosure_filename" do
    let(:episode) { create(:episode_with_media, podcast: podcast) }

    it "should return the filename from the enclosure url" do
      assert_equal "audio.flac", apple_episode.enclosure_filename
    end

    it "uses the private feed enclosure" do
      private_feed.enclosure_template = "http://foo.bar/any/where/whatev{feed_extension}"
      assert_equal "whatev.flac", apple_episode.enclosure_filename
    end
  end

  describe "#publish" do
    it "should call poll! at the conclusion of the episode publishing" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_api, apple_show, [apple_episode]])

      apple_api.stub(:bridge_remote_and_retry!, [{
        request_metadata: {
          apple_episode_id: apple_episode.apple_id,
          guid: apple_episode.guid
        },
        api_url: "asdf/",
        api_parameters: "ARBITRARY"
      }.with_indifferent_access]) do
        Apple::Episode.stub(:poll_episode_state, mock) do
          Apple::Episode.publish(apple_api, apple_show, [apple_episode])
        end
      end

      assert mock.verify
    end
  end

  describe "#archive" do
    it "should delegate to the alter_publish_state" do
      mock = Minitest::Mock.new
      mock.expect(:call, [], [apple_api, apple_show, [apple_episode], "ARCHIVE"])

      apple_api.stub(:bridge_remote_and_retry, nil) do
        Apple::Episode.stub(:alter_publish_state, mock) do
          Apple::Episode.archive(apple_api, apple_show, [apple_episode])
        end
      end

      assert mock.verify
    end
  end

  describe ".prepare_for_delivery" do
    it "should filter for episodes that need delivery" do
      mock = Minitest::Mock.new
      mock.expect(:call, true, [])

      apple_episode.feeder_episode.stub(:apple_prepare_for_delivery!, mock) do
        apple_episode.stub(:needs_delivery?, true) do
          assert_equal [apple_episode], Apple::Episode.prepare_for_delivery([apple_episode])
        end
      end

      mock.verify
    end

    it "should reject delivered episodes" do
      apple_episode.stub(:needs_delivery?, false) do
        assert_equal [], Apple::Episode.prepare_for_delivery([apple_episode])
      end
    end

    describe "soft deleting the delivery files" do
      let(:container) { create(:apple_podcast_container, episode: episode, apple_episode_id: "123") }

      let(:delivery) do
        pd = Apple::PodcastDelivery.new(episode: episode, podcast_container: container)
        pd.save!
        pd
      end

      let(:delivery_file) do
        pdf = Apple::PodcastDeliveryFile.new(episode: episode, podcast_delivery: delivery)
        pdf.update(apple_sync_log: SyncLog.new(**build(:podcast_delivery_file_api_response).merge(external_id: "123"), feeder_type: :podcast_delivery_files))
        pdf.save!
        pdf
      end

      before do
        assert_equal [delivery_file], apple_episode.podcast_delivery_files
      end

      it "should delete the delivery files" do
        assert apple_episode.podcast_delivery_files.length == 1

        apple_episode.stub(:needs_delivery?, true) do
          assert_equal [apple_episode], Apple::Episode.prepare_for_delivery([apple_episode])
        end

        assert apple_episode.podcast_delivery_files.length == 0
      end
    end
  end
end
