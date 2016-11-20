# encoding: utf-8

class Api::PodcastRepresenter < Api::BaseRepresenter
  property :prx_uri
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
end
