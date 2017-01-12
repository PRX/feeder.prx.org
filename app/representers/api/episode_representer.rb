# encoding: utf-8

class Api::EpisodeRepresenter < Api::BaseRepresenter
  # the guid that shows up in the rss feed
  # same as id by default, if overridden, can be different from id
  property :item_guid, as: :guid

  # the guid generated by feeder, used in API requests
  property :guid, as: :id, writable: false

  property :prx_uri
  property :created_at
  property :updated_at
  property :published_at

  property :url
  property :image_url

  property :title
  property :subtitle
  property :content
  property :summary
  property :description

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

  def self_url(episode)
    api_episode_path(id: episode.guid)
  end

  link rel: :podcast, writeable: true do
    api_podcast_path(represented.podcast) if represented.id
  end

  link :story do
    URI.join(cms_root, represented.prx_uri).to_s if represented.prx_uri
  end
end
