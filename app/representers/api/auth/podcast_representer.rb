class Api::Auth::PodcastRepresenter < Api::PodcastRepresenter
  property :deleted_at, writeable: false

  def self_url(podcast)
    api_authorization_podcast_path(podcast)
  end

  # point to authorized episodes (including unpublished)
  link :episodes do
    if represented.id
      {
        href: api_authorization_podcast_episodes_path(represented) + "{?page,per,zoom,since}",
        count: represented.episodes.count,
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
        count: represented.feeds.count,
        templated: true
      }
    end
  end
end
