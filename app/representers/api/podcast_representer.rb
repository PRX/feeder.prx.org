class Api::PodcastRepresenter < Api::BaseRepresenter
  property :id, writeable: false
  property :created_at, writeable: false
  property :updated_at, writeable: false

  property :prx_uri
  property :prx_account_uri
  property :source_url
  property :published_at

  property :published_url, writeable: false
  property :path
  property :url
  property :new_feed_url
  property :feedburner_url
  property :link

  property :title
  property :subtitle
  property :description
  property :summary
  property :summary_preview, exec_context: :decorator, if: ->(_o) { represented.summary.blank? }
  property :itunes_block

  property :explicit
  property :serial_order
  property :complete
  property :copyright
  property :language
  property :locked
  property :payment_pointer
  property :donation_url

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

  collection :categories
  collection :restrictions

  collection :itunes_categories, decorator: Api::ITunesCategoryRepresenter, class: ITunesCategory
  property :itunes_image, decorator: Api::ImageRepresenter, class: ITunesImage
  property :feed_image, decorator: Api::ImageRepresenter, class: FeedImage

  property :enclosure_template
  property :enclosure_prefix
  property :display_episodes_count
  property :display_full_episodes_count

  link :episodes do
    if represented.id
      {
        href: api_podcast_episodes_path(represented),
        count: represented.episodes.published.count
      }
    end
  end

  link :guid do
    if represented.id
      {
        href: api_podcast_guid_path_template(podcast_id: represented.id.to_s, id: "{guid}"),
        templated: true
      }
    end
  end

  link :series do
    URI.join(cms_root, represented.prx_uri).to_s if represented.prx_uri
  end

  link :account do
    URI.join(cms_root, represented.prx_account_uri).to_s if represented.prx_account_uri
  end
end
