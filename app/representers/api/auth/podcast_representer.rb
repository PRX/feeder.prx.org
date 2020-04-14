class Api::Auth::PodcastRepresenter < Api::PodcastRepresenter
  def self_url(podcast)
    api_authorization_podcast_path(podcast)
  end

  # point to authorized episodes (including unpublished)
  link :episodes do
    {
      href: api_authorization_podcast_episodes_path(represented) + '{?page,per,zoom,since}',
      count: represented.episodes.count,
      templated: true
    } if represented.id
  end
end
