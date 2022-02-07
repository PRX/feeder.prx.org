class Api::Auth::FeedRepresenter < Api::BaseRepresenter
  property :id, writable: false
  property :created_at, writable: false
  property :updated_at, writable: false

  property :slug
  property :private
  property :audio_format
  property :include_zones

  def self_url(feed)    
    api_authorization_podcast_feed_path(podcast_id: feed.podcast_id, id: feed.id)
  end

  link :podcast do
    api_authorization_podcast_path(represented.podcast) if represented.id && represented.podcast
  end
end