# encoding: utf-8

class Api::PodcastRepresenter < Api::BaseRepresenter
  property :id
  property :prx_uri
  property :prx_account_uri
  property :source_url
  property :created_at
  property :updated_at
  property :published_at

  property :path
  property :url
  property :published_url, writeable: false
  property :new_feed_url
  property :feedburner_url
  property :link

  property :title
  property :subtitle
  property :description
  property :summary

  property :explicit
  property :complete
  property :copyright
  property :language

  nested :owner do
    property :owner_name, as: :name
    property :owner_email, as: :email
  end

  nested :author do
    property :author_name, as: :name
    property :author_email, as: :email
  end

  nested :managing_editor do
    property :managing_editor_name, as: :name
    property :managing_editor_email, as: :email
  end

  collection :keywords
  collection :categories

  collection :itunes_categories, decorator: Api::ITunesCategoryRepresenter, class: ITunesCategory
  property :itunes_image, decorator: Api::ImageRepresenter, class: ITunesImage
  property :feed_image, decorator: Api::ImageRepresenter, class: FeedImage

  property :enclosure_template
  property :display_episodes_count
  property :display_full_episodes_count

  link :episodes do
    {
      href: api_podcast_episodes_path(represented),
      count: represented.episodes.published.released.count
    } if represented.id
  end

  link :series do
    URI.join(cms_root, represented.prx_uri).to_s if represented.prx_uri
  end

  link :account do
    URI.join(cms_root, represented.prx_account_uri).to_s if represented.prx_account_uri
  end
end
