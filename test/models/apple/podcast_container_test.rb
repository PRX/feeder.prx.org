# frozen_string_literal: true

require 'test_helper'

class Apple::PodcastContainerTest < ActiveSupport::TestCase
  let(:podcast) { create(:podcast) }
  let(:episode) { create(:episode, podcast: podcast) }

  let(:apple_creds) { build(:apple_credential) }
  let(:apple_api) { Apple::Api.from_apple_credentials(apple_creds) }
  let(:public_feed) { create(:feed, podcast: podcast, private: false) }
  let(:private_feed) { create(:feed, podcast: podcast, private: true) }
  let(:apple_show) { Apple::Show.new(api: apple_api, public_feed: public_feed, private_feed: private_feed) }

  let(:apple_episode) { build(:apple_episode, show: apple_show, feeder_episode: episode) }

  let(:apple_episode_id) { 'apple-ep-id' }
  let(:apple_audio_asset_vendor_id) { 'apple-vendor-id' }
  let(:podcast_container_json_row) do
    { 'request_metadata' => { 'apple_episode_id' => apple_episode_id },
      'api_response' => { 'val' => { 'data' =>
     { 'type' => 'podcastContainers',
       'id' => '1234' } } } }
  end

  let(:api) { build(:apple_api) }

  describe '.upsert_podcast_containers' do
    it 'should create logs based on a returned row value' do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          assert_equal SyncLog.count, 0
          assert_equal Apple::PodcastContainer.count, 0

          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
                                                           podcast_container_json_row)
          assert_equal SyncLog.count, 1
          assert_equal Apple::PodcastContainer.count, 1

          Apple::PodcastContainer.upsert_podcast_container(apple_episode,
                                                           podcast_container_json_row)

          assert_equal SyncLog.count, 2
          assert_equal Apple::PodcastContainer.count, 1
        end
      end
    end

    it 'should update timestamps when upserting' do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
          pc1 = Apple::PodcastContainer.upsert_podcast_container(apple_episode,
                                                                 podcast_container_json_row)

          pc1.update(updated_at: Time.now - 1.year)
          # upsert
          pc2 = Apple::PodcastContainer.upsert_podcast_container(apple_episode,
                                                                 podcast_container_json_row.merge({ foo: 'bar' }))

          assert pc1 == pc2
          assert pc2.updated_at > pc1.updated_at
        end
      end
    end

    it 'should update the source_url and source_file_name' do
      apple_episode.stub(:apple_id, apple_episode_id) do
        apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do

          pc1 = nil
          apple_episode.stub(:enclosure_url, 'https://podcast.source/1234') do
            apple_episode.stub(:enclosure_filename, '1234') do
              pc1 = Apple::PodcastContainer.upsert_podcast_container(apple_episode,
                                                                     podcast_container_json_row)
              assert_equal pc1.source_url, 'https://podcast.source/1234'
              assert_equal pc1.source_filename, '1234'
            end
          end

          pc2 = nil
          apple_episode.stub(:enclosure_url, 'https://another.source/5678') do
            apple_episode.stub(:enclosure_filename, '5678') do
              pc2 = Apple::PodcastContainer.upsert_podcast_container(apple_episode,
                                                                     podcast_container_json_row)
            end
          end

          assert pc1 == pc2

          assert_equal pc2.source_url, 'https://another.source/5678'
          assert_equal pc2.source_filename, '5678'
        end
      end
    end
  end

  describe '.update_podcast_container_state(api, episodes)' do
    it 'creates new records if they dont exist' do
      assert_equal SyncLog.count, 0

      Apple::PodcastContainer.stub(:get_podcast_containers_via_episodes, [podcast_container_json_row]) do
        apple_episode.stub(:apple_id, apple_episode_id) do
          apple_episode.stub(:audio_asset_vendor_id, apple_audio_asset_vendor_id) do
            Apple::PodcastContainer.update_podcast_container_state(nil, [apple_episode])
          end
        end
      end
      assert_equal SyncLog.count, 1
    end
  end

  describe '#podcast_deliveries' do
    let(:container) { Apple::PodcastContainer.new }
    it 'should have many deliveries' do
      assert_equal [], container.podcast_deliveries
      pd = container.podcast_deliveries.build
      assert_equal Apple::PodcastDelivery, pd.class
    end
  end

  describe '.get_podcast_containers_bridge_params' do
    it 'should set the apple episode id in the request metadata' do
      apple_episode.stub(:audio_asset_vendor_id, 'some-vendor-id') do
        apple_episode.stub(:apple_id, 'ap-ep-id') do
          res = Apple::PodcastContainer.get_podcast_containers_bridge_params(api, [apple_episode])
          bridge_param = res.first
          assert_equal bridge_param[:request_metadata].fetch(:apple_episode_id), apple_episode.apple_id
        end
      end
    end
  end

  describe '.podcast_container_url' do
    it 'raises an error if the vendor id is missing' do
      assert_raises(RuntimeError, 'incomplete api response') do
        Apple::PodcastContainer.podcast_container_url(api, OpenStruct.new)
      end
    end
  end
end
