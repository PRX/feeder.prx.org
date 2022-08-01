# frozen_string_literal: true

class Apple::Publisher

  attr_reader :feed,
              :api,
              :show

  def initialize(feed)
    @feed = feed
    @api = Apple::Api.from_env
    @show = Apple::Show.new(@feed)
  end

  def podcast
    feed.podcast
  end

  def publish!

    show.sync!

  rescue Apple::ApiError => e
    puts e
    sync = SyncLog.create!(feeder_id: feed.id, feeder_type: 'f')
  end

  def episode_podcast_container_url(vendor_id)
      api.join_url('podcastContainers?filter[vendorId]=' + vendor_id).to_s
  end

  def get_podcast_containers
    resp =
      api.bridge_get('podcastContainers', get_episode_asset_container_metadata)

    api.unwrap_response(resp)
  end

  def get_episode_asset_container_metadata
    return unless show.id.present?

    show.get_episodes.map do |ep|
      vendor_id = ep['attributes']['appleHostedAudioAssetVendorId']

      {
        apple_episode_id: ep['id'],
        audio_asset_vendor_id: vendor_id,
        podcast_containers_url: episode_podcast_container_url(vendor_id)
      }
    end
  end

  def get_episode_asset_container_metadata
    return unless show.id.present?

    show.get_episodes.map do |ep|
      vendor_id = ep['attributes']['appleHostedAudioAssetVendorId']

      {
        apple_episode_id: ep['id'],
        audio_asset_vendor_id: vendor_id,
        podcast_containers_url: episode_podcast_container_url(vendor_id)
      }
    end
  end

  def episode_podcast_container_url(vendor_id)
      api.join_url('podcastContainers?filter[vendorId]=' + vendor_id).to_s
  end

  def get_podcast_containers
    resp =
      api.bridge_get('podcastContainers', get_episode_asset_container_metadata)

    api.unwrap_response(resp)
  end
end
