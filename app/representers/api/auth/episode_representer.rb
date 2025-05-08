class Api::Auth::EpisodeRepresenter < Api::EpisodeRepresenter
  property :deleted_at, writeable: false
  property :feed_slugs

  collection :media,
    decorator: Api::Auth::MediaResourceRepresenter,
    class: MediaResource

  # render previous/deleted media_version, if current isn't ready
  collection :complete_media,
    as: :ready_media,
    decorator: Api::Auth::MediaResourceRepresenter,
    class: MediaResource,
    writeable: false,
    if: ->(_o) { !media_ready?(true) && complete_media? }

  property :uncut, decorator: Api::Auth::UncutRepresenter, class: Uncut

  def self_url(episode)
    api_authorization_episode_path(id: episode.guid)
  end
end
