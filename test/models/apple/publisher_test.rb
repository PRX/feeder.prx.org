# frozen_string_literal: true

require "test_helper"

describe Apple::Publisher do
  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:apple_publisher) { Apple::Publisher.new(feed) }

  before do
    stub_request(:get, "https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200").
      to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe "episode related data" do
    let(:episode) { create(:episode, podcast: podcast) }

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
  end
end
