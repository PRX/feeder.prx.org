# frozen_string_literal: true

require 'test_helper'

describe Apple::Publisher do

  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:apple_publisher) { Apple::Publisher.new(feed) }

  before do
   stub_request(:get, 'https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200').
     to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe 'episode related data' do

    let(:episode) { create(:episode, podcast: podcast) }

    let(:apple_episode_json) do
        { id: '123',
          attributes: {
            appleHostedAudioAssetVendorId: '456',
            guid: episode.item_guid }
        }.with_indifferent_access

    end

    let(:apple_episode_list) do
      [
        apple_episode_json
      ]
    end

    describe '#get_episode_asset_container_metadata' do
      it 'fetches a list ofmetadata associated by episode id' do
        apple_publisher.stub(:get_episodes, apple_episode_list) do
          assert_equal apple_publisher.get_episode_asset_container_metadata, [{:apple_episode_id=>"123",
                                                                          :audio_asset_vendor_id=>"456",
                                                                          :podcast_containers_url=>"https://api.podcastsconnect.apple.com/v1/podcastContainers?filter[vendorId]=456"}]
        end
      end
    end

    describe '#episode_podcast_container_url' do
      it 'wraps the vendor id in a apple api url' do
        assert_equal apple_publisher.episode_podcast_container_url('1234'), 'https://api.podcastsconnect.apple.com/v1/podcastContainers?filter[vendorId]=1234'
      end
    end
  end
end
