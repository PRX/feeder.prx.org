# frozen_string_literal: true

class Apple::Episode

  attr_reader :show, :episode, :api

  def initialize(show, episode)
    @show = show
    @episode = episode
    @api = Apple::Api.from_env
  end

  def json
    eps = show.get_episodes

    eps.find { |ep| ep['attributes']['guid'] == episode.item_guid }
  end

  alias_method :apple_json, :json

  def completed_sync_log
    SyncLog.
      episodes.
      complete.
      where(feeder_id: episode.id, feeder_type: 'e', external_type: nil).
      order(id: :desc).
      first
  end

  def create_or_update_episode!
    json =
      if apple_json.nil?
        create_episode!
      else
        update_episode! if apple_only?
      end

    external_id = json&.dig('data', 'id') || nil
    episode_sync_completed = external_id.present?

    sync = SyncLog.create!(feeder_id: feeder_id,
                  feeder_type: 'e',
                  sync_completed_at: episode_sync_completed ? Time.now.utc : nil,
                  external_id: external_id)

    sync
  end

  def apple?
    episode.apple?
  end

  def apple_only?
    episode.apple_only?
  end

  def sync!
    create_or_update_episode!
  rescue Apple::ApiError => e
    sync = SyncLog.create!(feeder_id: episode.id, feeder_type: 'e')
  end

  def create_episode_data
    explicit = episode.explicit.present? && episode.explicit == 'true'

    {
      data:
      {
        type: 'episodes',
        attributes:{
          guid: episode.item_guid,
          title: episode.title,
          originalReleaseDate: episode.published_at.utc.iso8601,
          description: episode.description || episode.subtitle,
          websiteUrl: episode.url,
          explicit: explicit,
          episodeNumber: episode.episode_number,
          seasonNumber: episode.season_number,
          episodeType: episode.itunes_type.upcase,
          appleHostedAudioIsSubscriberOnly: true
        },
        relationships: {
          show: {data: {type: 'shows', id: show.id}}
        }
      }
    }
  end

  def update_episode_data
    data  = create_episode_data
    data[:data][:id] = id
    data[:data][:attributes].delete(:guid)
    data[:data][:relationships].delete(:show)

    data
  end

  def podcast_container_bridge_options(container_response)
    container_list = container_response['podcast_container_response']['data']

  end

  def create_episode!
    resp = api.post('episodes', create_episode_data)

    api.unwrap_response(resp)
  end

  def update_episode!
    resp = api.patch('episodes/' + id , update_episode_data)

    api.unwrap_response(resp)
  end

  def audio_asset_vendor_id
    apple_json&.dig('attributes', 'appleHostedAudioAssetVendorId')
  end

  def id
    apple_json&.dig('id')
  end

  def feeder_id
    episode.id
  end

  def podcast_containers
    resp = api.get('podcastContainers?filter[vendorId]=' + audio_asset_vendor_id)

    json = api.unwrap_response(resp)
    json['data']
  end

  def podcast_container_url
      api.join_url('podcastContainers?filter[vendorId]=' + audio_asset_vendor_id).to_s
  end

  def podcast_container_create_parameters
    {
      'data': {
        'type': 'podcastContainers',
        'attributes': {
          'vendorId': audio_asset_vendor_id
        }
      }
    }
  end
end

