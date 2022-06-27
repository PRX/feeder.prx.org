class Api::Auth::FeedRepresenter < Api::BaseRepresenter
  property :id, writable: false
  property :created_at, writable: false
  property :updated_at, writable: false

  property :slug
  property :file_name
  property :private
  property :title
  property :url
  property :new_feed_url
  property :enclosure_prefix
  property :display_episodes_count
  property :display_full_episodes_count
  property :episode_offset_seconds
  property :include_zones
  property :include_tags
  property :audio_format

  collection :feed_tokens,
             as: :tokens,
             decorator: Api::FeedTokenRepresenter,
             class: FeedToken

  def self_url(feed)    
    api_authorization_podcast_feed_path(podcast_id: feed.podcast_id, id: feed.id)
  end

  link :podcast do
    api_authorization_podcast_path(represented.podcast) if represented.id && represented.podcast
  end

  link :private_feed do
    {
      href: represented.published_url + auth_param_format,
      templated: true,
      type: 'application/rss+xml'
    }
  end

  def auth_param_format
    if represented.private?
      '{?auth}'
    else
      ''
    end
  end
end
