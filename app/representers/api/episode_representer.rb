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
  property :content
  property :summary
  property :summary_preview,
    exec_context: :decorator, if: ->(_o) { !represented.summary }
  property :season_number
  property :episode_number
  property :itunes_type
  property :itunes_block

  property :explicit
  property :block
  property :is_closed_captioned
  property :is_perma_link
  property :include_in_feed?, as: :is_feed_ready
  property :duration
  property :keywords
  property :categories
  property :position

  nested :author do
    property :author_name, as: :name
    property :author_email, as: :email
  end

  property :audio_version
  property :segment_count
  collection :media_files,
    as: :media,
    decorator: Api::MediaResourceRepresenter,
    class: MediaResource

  collection :images, decorator: Api::ImageRepresenter, class: EpisodeImage

  def self_url(episode)
    api_episode_path(id: episode.guid)
  end

  link :enclosure do
    if represented.podcast && represented.media?
      {
        href: represented.enclosure_url,
        type: represented.content_type,
        size: represented.file_size,
        duration: represented.duration.to_i,
        status: represented.media_status
      }
    end
  end

  link rel: :podcast, writeable: true do
    api_podcast_path(represented.podcast) if represented.id && represented.podcast
  end

  link :story do
    URI.join(cms_root, represented.prx_uri).to_s if represented.prx_uri
  end

  link :audio_version do
    URI.join(cms_root, represented.prx_audio_version_uri).to_s if represented.prx_audio_version_uri
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
