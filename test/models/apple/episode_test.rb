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
      assert_equal apple_episode.apple_id, "123"
      assert_equal apple_episode.audio_asset_vendor_id, "456"
      assert_equal apple_episode.drafting?, true
      assert_equal apple_episode.guid, episode.item_guid
    end

    it "instantiates with a nil api_response" do
      ep = build(:apple_episode, show: apple_show, feeder_episode: episode, api_response: nil)
      assert_nil ep.apple_id
      assert_nil ep.audio_asset_vendor_id
      # It does not exists yet, so it is not drafting
      assert_equal false, ep.drafting?
      # Comes from the feeder model
      assert_equal episode.item_guid, ep.guid
    end
  end

  describe "#completed_sync_log" do
    it "should load the last sync log if complete" do
      sync_log = SyncLog.create!(feeder_id: episode.id,
        feeder_type: :episodes,
        sync_completed_at: Time.now.utc,
        external_id: "1234")

      assert_equal apple_episode.completed_sync_log, sync_log
    end

    it "returns nil if nothing is completed" do
      assert_nil apple_episode.completed_sync_log
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
end
