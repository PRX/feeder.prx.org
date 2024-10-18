class Api::EpisodeRepresenter < Api::BaseRepresenter
  # the guid generated by feeder, used in API requests
  property :guid, as: :id, writable: false
  property :created_at, writable: false
  property :updated_at, writable: false

  # based on the podcast explicit and the episode explicit values: true, false, and nil
  property :explicit_content, writeable: false

  # the guid that shows up in the rss feed
  # based on id by default, if updated, can be set to anything
  property :item_guid, as: :guid
  property :prx_uri
  property :published_at
  property :released_at

  # combo of published_at, guid, and title at time of first scheduling for publication
  property :keyword_xid, writeable: false

  property :url

  property :title
  property :clean_title
  property :subtitle
  property :description
  property :season_number
  property :episode_number
  property :itunes_type
  property :itunes_block

  property :explicit
  property :block
  property :is_closed_captioned
  property :is_perma_link
  property :feed_ready?, as: :is_feed_ready
  property :categories
  property :position

  nested :author do
    property :author_name, as: :name
    property :author_email, as: :email
  end

  property :segment_count
  property :media_version_id, as: :media_version, writeable: false

  collection :media,
    decorator: Api::MediaResourceRepresenter,
    class: MediaResource

  property :image, decorator: Api::ImageRepresenter, class: EpisodeImage

  def self_url(episode)
    api_episode_path(id: episode.guid)
  end

  link :enclosure do
    if represented.podcast && represented.media?
      {
        href: represented.enclosure_url,
        type: represented.media_content_type,
        size: represented.media_file_size,
        duration: represented.media_duration.to_i,
        status: represented.media_status
      }
    end
  end

  link rel: :podcast, writeable: true do
    api_podcast_path(represented.podcast) if represented.id && represented.podcast
  end

  link :podcast_feed do
    if represented.podcast_feed_url
      {
        href: represented.podcast_feed_url,
        type: "application/rss+xml",
        title: represented.podcast.title
      }
    end
  end
end
