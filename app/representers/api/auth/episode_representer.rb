class Api::Auth::EpisodeRepresenter < Api::EpisodeRepresenter
  def self_url(episode)
    api_authorization_episode_path(id: episode.guid)
  end
end
