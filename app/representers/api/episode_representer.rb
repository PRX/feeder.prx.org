# encoding: utf-8

class Api::EpisodeRepresenter < Api::BaseRepresenter
  property :guid
  property :original_guid
  property :prx_uri
  property :created_at
  property :updated_at
  property :published_at
  property :released_at

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

  link :podcast do
    api_podcast_path(represented.podcast) if represented.id
  end

  link :story do
    URI.join(cms_root, represented.prx_uri).to_s if represented.id
  end
end
