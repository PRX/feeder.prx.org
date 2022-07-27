# frozen_string_literal: true

require 'test_helper'

describe Apple::Show do

  let(:podcast) { create(:podcast) }
  let(:feed) { create(:feed, podcast: podcast, private: false) }
  let(:apple_show) { Apple::Show.new(feed) }

  before do
   stub_request(:get, 'https://api.podcastsconnect.apple.com/v1/countriesAndRegions?limit=200').
     to_return(status: 200, body: json_file(:apple_countries_and_regions), headers: {})
  end

  describe '#sync!' do
    it 'runs sync!' do

      apple_show.stub(:create_or_update_show, {'data' => {'id' => '123'}}) do

        sync = apple_show.sync!

        assert_equal sync.class, SyncLog
        assert_equal sync.complete?, true
      end
    end

    it 'logs an incomplete sync record if the upsert fails' do
      raises_exception = -> (arg) { raise Apple::ApiError.new(arg) }
      apple_show.stub(:create_or_update_show, raises_exception) do
        sync = apple_show.sync!

        assert_equal sync.complete?, false
      end
    end
  end

  describe '#show_data' do
    it 'returns a hash' do
      assert_equal apple_show.show_data.class, Hash
    end
  end

  describe '#feed_published_url' do

    before do
      feed.podcast.feeds.update_all(private: true)
      feed.podcast.feeds.map { |f| f.tokens.build.save! }
      apple_show.podcast.reload
    end

    it 'returns an authed url if private' do
      assert_equal apple_show.feed_published_url, feed.podcast.published_url + "?auth=#{podcast.default_feed.tokens.first.token}"
    end

    it 'raises an error when there is no token' do
      # a private feed with no tokens
      podcast.feeds.map { |f| f.tokens.delete_all }
      apple_show.podcast.reload

      assert_raise(RuntimeError) do
        apple_show.feed_published_url
      end
    end
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
        apple_show.stub(:get_episodes, apple_episode_list) do
          assert_equal apple_show.get_episode_asset_container_metadata, [{:apple_episode_id=>"123",
                                                                          :audio_asset_vendor_id=>"456",
                                                                          :podcast_containers_url=>"https://api.podcastsconnect.apple.com/v1/podcastContainers?filter[vendorId]=456"}]
        end
      end
    end

    describe '#episode_podcast_container_url' do
      it 'wraps the vendor id in a apple api url' do
        assert_equal apple_show.episode_podcast_container_url('1234'), 'https://api.podcastsconnect.apple.com/v1/podcastContainers?filter[vendorId]=1234'
      end
    end
  end
end
