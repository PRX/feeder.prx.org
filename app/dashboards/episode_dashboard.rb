require "administrate/base_dashboard"

class EpisodeDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    audio_version: Field::String,
    author_email: Field::String,
    author_name: Field::String,
    block: Field::Boolean,
    categories: Field::String,
    clean_title: Field::Text,
    content: Field::Text,
    deleted_at: Field::DateTime,
    description: Field::Text,
    enclosure_override_prefix: Field::Boolean,
    enclosure_override_url: Field::String,
    episode_number: Field::Number,
    explicit: Field::String,
    feedburner_orig_enclosure_link: Field::String,
    feedburner_orig_link: Field::String,
    first_rss_published_at: Field::DateTime,
    guid: Field::String,
    is_closed_captioned: Field::Boolean,
    is_perma_link: Field::Boolean,
    itunes_block: Field::Boolean,
    itunes_type: Field::String,
    keyword_xid: Field::String,
    lock_version: Field::Number,
    medium: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    original_guid: Field::String,
    overrides: Field::Text,
    podcast: Field::BelongsTo,
    position: Field::Number,
    production_notes: Field::Text,
    prx_audio_version_uri: Field::String,
    prx_uri: Field::String,
    published_at: Field::DateTime,
    released_at: Field::DateTime,
    season_number: Field::Number,
    segment_count: Field::Number,
    source_updated_at: Field::DateTime,
    subtitle: Field::Text,
    summary: Field::Text,
    title: Field::Text,
    url: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    guid
    title
    published_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    audio_version
    author_email
    author_name
    block
    categories
    clean_title
    content
    deleted_at
    description
    enclosure_override_prefix
    enclosure_override_url
    episode_number
    explicit
    feedburner_orig_enclosure_link
    feedburner_orig_link
    first_rss_published_at
    guid
    is_closed_captioned
    is_perma_link
    itunes_block
    itunes_type
    keyword_xid
    lock_version
    medium
    original_guid
    overrides
    podcast
    position
    production_notes
    prx_audio_version_uri
    prx_uri
    published_at
    released_at
    season_number
    segment_count
    source_updated_at
    subtitle
    summary
    title
    url
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    audio_version
    author_email
    author_name
    block
    categories
    clean_title
    content
    deleted_at
    description
    enclosure_override_prefix
    enclosure_override_url
    episode_number
    explicit
    feedburner_orig_enclosure_link
    feedburner_orig_link
    first_rss_published_at
    guid
    is_closed_captioned
    is_perma_link
    itunes_block
    itunes_type
    keyword_xid
    lock_version
    medium
    original_guid
    overrides
    podcast
    position
    production_notes
    prx_audio_version_uri
    prx_uri
    published_at
    released_at
    season_number
    segment_count
    source_updated_at
    subtitle
    summary
    title
    url
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how episodes are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(episode)
  #   "Episode ##{episode.id}"
  # end
end
