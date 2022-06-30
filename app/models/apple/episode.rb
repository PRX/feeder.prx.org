# frozen_string_literal: true

class Apple::Episode

  attr_reader :show, :episode, :api

  def initialize(show, episode)
    @show = show
    @episode = episode
    @api = Apple::Api.from_env
  end

  def scan_for_self
    eps = show.get_episodes

    eps.find { |ep| ep['attributes']['guid'] == episode.item_guid }
  end

  def completed_sync_log
    SyncLog.
      feeds.
      complete.
      where(feeder_id: episode.id, feeder_type: 'e').
      order(created_at: :desc)
  end

  def sync!
    remote_apple_episode = scan_for_self

    json = {}
    if remote_apple_episode.nil?
      json = create_episode(sync, remote_apple_episode['id'])
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
          originalReleaseDate: episode.published_at,
          description: episode.description,
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

  def create_episode
    api.post
    create_episode(sync, apple_episode_id)
  end
end
