class Api::Auth::PodcastRepresenter < Api::PodcastRepresenter
  property :deleted_at, writeable: false

  # TODO: this should probably be embedded, but zooms aren't working!
  # update when we move off hal_api-rails (probably to halbuilder)
  collection :feeds, writeable: false do
    property :id
    property :label
    property :slug
    property :private
    property :auth_token, as: :auth
  end

  def self_url(podcast)
    api_authorization_podcast_path(podcast)
  end

  # point to authorized episodes (including unpublished)
  link :episodes do
    if represented.id
      {
        href: api_authorization_podcast_episodes_path(represented) + "{?page,per,zoom,since}",
        templated: true
      }
    end
  end

  # point to authorized item guids (including unpublished)
  link :guid do
    if represented.id
      {
        href: api_authorization_podcast_guid_path_template(podcast_id: represented.id.to_s, id: "{guid}"),
        templated: true
      }
    end
  end

  # point to authorized feeds (including private)
  link :feeds do
    if represented.id
      {
        href: api_authorization_podcast_feeds_path(represented) + "{?page,per,zoom,since}",
        templated: true
      }
    end
  end
end
