class Api::Auth::EpisodeRepresenter < Api::EpisodeRepresenter
  property :deleted_at, writeable: false

  def self_url(episode)
    api_authorization_episode_path(id: episode.guid)
  end
end
