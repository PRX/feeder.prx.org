# encoding: utf-8

class Api::EpisodeRepresenter < Api::BaseRepresenter
  # the guid generated by feeder, used in API requests
  property :guid, as: :id, writable: false
  property :created_at, writable: false
  property :updated_at, writable: false

  # the guid that shows up in the rss feed
  # based on id by default, if updated, can be set to anything
  property :item_guid, as: :guid
  property :prx_uri
  property :published_at

  # combo of published_at, guid, and title at time of first scheduling for publication
  property :keyword_xid, writeable: false

  property :url

  property :title
  property :clean_title
  property :subtitle
  property :description
  property :content
  property :summary
  property :summary_preview, exec_context: :decorator, if: ->(_o) { !represented.summary }
  property :season_number
  property :episode_number
  property :itunes_type

  property :explicit
  property :block
  property :is_closed_captioned
  property :is_perma_link
  property :duration
  property :keywords
  property :categories
  property :position

  nested :author do
    property :author_name, as: :name
    property :author_email, as: :email
  end

  collection :media_files,
    as: :media,
    decorator: MediaResourceRepresenter,
    class: MediaResource

  collection :images,
    decorator: ImageRepresenter,
    class: EpisodeImage

  def self_url(episode)
    api_episode_path(id: episode.guid)
  end

  link :enclosure do
    {
      href: represented.media_url,
      type: represented.content_type,
      size: represented.file_size,
      duration: represented.duration.to_i,
      status: represented.media_status
    } if represented.media?
  end

  link rel: :podcast, writeable: true do
    api_podcast_path(represented.podcast) if represented.id
  end

  link :story do
    URI.join(cms_root, represented.prx_uri).to_s if represented.prx_uri
  end
end
