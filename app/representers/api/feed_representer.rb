class Api::FeedRepresenter < Api::BaseRepresenter
  property :id, writable: false
  property :created_at, writable: false
  property :updated_at, writable: false

  property :name
  property :overrides

  def self_url(feed)
    api_podcast_feed_path(podcast_id: feed.podcast_id, id: feed.id)
  end

  link :podcast do
    api_podcast_path(represented.podcast) if represented.id && represented.podcast
  end
end
