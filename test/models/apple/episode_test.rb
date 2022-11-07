# frozen_string_literal: true

require "test_helper"

describe Apple::Episode do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:episode) { create(:episode, podcast: podcast) }
  let(:apple_show) { Apple::Show.new(feed) }
  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200").
      to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe "#apple_json" do
    let(:apple_episode_json) do
      { id: "123",
        attributes: {
          appleHostedAudioAssetVendorId: "456",
          guid: episode.item_guid
        } }.with_indifferent_access
    end

    let(:apple_episode_list) do
      [
        apple_episode_json
      ]
    end

    it "fetches the apple json via the show" do
      apple_show.stub(:apple_id, 'apple_id') do
        apple_show.stub(:get_episodes, apple_episode_list) do
          assert_equal apple_episode.apple_json, apple_episode_json
        end
      end
    end

    it "lets you access various attributes" do
      apple_show.stub(:apple_id, 'apple_id') do
        apple_show.stub(:get_episodes, apple_episode_list) do
          assert_equal apple_episode.id, "123"
          assert_equal apple_episode.audio_asset_vendor_id, "456"
        end
      end
    end
  end

  describe "#completed_sync_log" do
    it "should load the last sync log if complete" do
      sync_log = SyncLog.create!(feeder_id: episode.id,
                                 feeder_type: :episodes,
                                 sync_completed_at:  Time.now.utc,
                                 external_id: "1234")

      assert_equal apple_episode.completed_sync_log, sync_log
    end

    it "returns nil if nothing is completed" do
      assert_nil apple_episode.completed_sync_log
    end
  end
end
