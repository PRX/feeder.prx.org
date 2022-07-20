# frozen_string_literal: true

class Apple::Episode

  attr_reader :show, :episode, :api

  def initialize(show, episode)
    @show = show
    @episode = episode
    @api = Apple::Api.from_env
  end

  def apple_json
    eps = show.get_episodes

    eps.find { |ep| ep['attributes']['guid'] == episode.item_guid }
  end

  def completed_sync_log
    SyncLog.
      episodes.
      complete.
      where(feeder_id: episode.id, feeder_type: 'e').
      order(id: :desc).
      first
  end

  def sync!
    remote_apple_episode = apple_episode

    json =
      if remote_apple_episode.nil?
        create_episode!
      else
        update_episode!
      end

    external_id = json.dig('data', 'id')
    sync_completed = external_id.present?

    SyncLog.create!(feeder_id: episode.id,
                    feeder_type: 'e',
                    sync_completed_at: sync_completed ? Time.now.utc : nil,
                    external_id: json.dig('data', 'id'))

  rescue Apple::ApiError => e
    sync = SyncLog.create!(feeder_id: episode.id, feeder_type: 'e')
  end

  def create_episode_data
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
          explicit: (episode.explicit.present? && episode.explicit),
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

  def create_episode!
    resp = api.post('episodes', create_episode_data)

    api.unwrap_response(resp)
  end

  def update_episode!
    resp = api.patch('episodes/' + id , update_episode_data)

    api.unwrap_response(resp)
  end

  def id
    get_episode&.dig('id')
  end

  def get_episode
    return nil unless scan_for_self.present?

    scan_for_self
  end
end

