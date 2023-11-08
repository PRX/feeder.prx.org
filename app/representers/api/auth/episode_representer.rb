class Api::Auth::EpisodeRepresenter < Api::EpisodeRepresenter
  property :deleted_at, writeable: false

  collection :media,
    decorator: Api::Auth::MediaResourceRepresenter,
    class: MediaResource

  collection :complete_media,
    as: :ready_media,
    decorator: Api::Auth::MediaResourceRepresenter,
    class: MediaResource,
    writeable: false,
    if: ->(_o) { !media_ready? && complete_media? }

  def self_url(episode)
    api_authorization_episode_path(id: episode.guid)
  end
end
