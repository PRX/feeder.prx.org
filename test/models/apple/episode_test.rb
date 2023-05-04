# frozen_string_literal: true

require "test_helper"

describe Apple::Episode do
  let(:podcast) { create(:podcast) }

  let(:public_feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:feed, podcast: podcast, private: true, tokens: [FeedToken.new]) }

  let(:apple_config) { build(:apple_config) }
  let(:apple_api) { Apple::Api.from_apple_config(apple_config) }

  let(:episode) { create(:episode, podcast: podcast) }
  let(:apple_show) do
    Apple::Show.new(api: apple_api,
      public_feed: public_feed,
      private_feed: private_feed)
  end
  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200")
      .to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe "#apple_json" do
    let(:apple_episode_json) do
      {id: "123",
       attributes: {
         appleHostedAudioAssetVendorId: "456",
         publishingState: "DRAFTING",
         guid: episode.item_guid
       }}.with_indifferent_access
    end

    let(:apple_episode_json_api_result) do
      {"request_metadata" => {"apple_episode_id" => "123", "item_guid" => episode.item_guid},
       "api_url" => "http://the-api-url.com/v1/episodes/123",
       "api_parameters" => {},
       "api_response" => {"ok" => true,
                          "err" => false,
                          "val" => {"data" => apple_episode_json}}}
    end

    let(:apple_episode_list) do
      [
        apple_episode_json
      ]
    end

    it "instantiates with an api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode, api_response: apple_episode_json_api_result)
      assert_equal "123", ep.apple_id
      assert_equal "456", ep.audio_asset_vendor_id
      assert_equal true, ep.drafting?, true
      assert_equal episode.item_guid, ep.guid
    end

    it "instantiates with a nil api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode)
      assert_nil ep.apple_id
      assert_raises(RuntimeError, "incomplete api response") { ep.audio_asset_vendor_id }
      # It does not exists yet, so it is not drafting
      assert_equal false, ep.drafting?
      # Comes from the feeder model
      assert_equal episode.item_guid, ep.guid
    end
  end

  describe "#enclosure_url" do
    it "should add a noImp query param" do
      assert_match(/noImp=1/, apple_episode.enclosure_url)
    end
  end

  describe "#enclosure_url" do
    it "should add a noImp query param" do
      assert_match(/noImp=1/, apple_episode.enclosure_url)
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
      pdf.update(apple_sync_log: SyncLog.new(**build(:podcast_delivery_file_api_response), feeder_type: :podcast_delivery_files))
      pdf.save!
      pdf
    end

    before do
      assert_equal [delivery_file], apple_episode.podcast_delivery_files
      apple_episode.apple_sync_log =
        SyncLog.new(feeder_type: :episodes, api_response:
        {"request_metadata" => {},
         "api_response" => {"ok" => true,
                            "err" => false,
                            "val" => {"data" => {"attributes" => {"appleHostedAudioAssetState" => "COMPLETE"}}}}})
    end

    it "should be true if all the conditions are met" do
      assert_equal true, apple_episode.waiting_for_asset_state?
    end

    it "should be false if there are no podcast delivery files" do
      apple_episode.stub(:podcast_delivery_files, []) do
        assert_equal false, apple_episode.waiting_for_asset_state?
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

      delivery_file.apple_sync_log.update!(**build(:podcast_delivery_file_api_response))
      apple_episode.podcast_delivery_files.reset

      assert_equal false, apple_episode.waiting_for_asset_state?
    end
  end
end
