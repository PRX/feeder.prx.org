require "administrate/base_dashboard"

class PodcastDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    author_email: Field::String,
    author_name: Field::String,
    categories: Field::String,
    complete: Field::Boolean,
    copyright: Field::String,
    deleted_at: Field::DateTime,
    donation_url: Field::String,
    duration_padding: Field::String.with_options(searchable: false),
    episodes: Field::HasMany,
    explicit: Field::String,
    feedburner_url: Field::String,
    guid: Field::String,
    itunes_block: Field::Boolean,
    language: Field::String,
    link: Field::String,
    lock_version: Field::Number,
    locked_until: Field::DateTime,
    managing_editor_email: Field::String,
    managing_editor_name: Field::String,
    max_episodes: Field::Number,
    owner_email: Field::String,
    owner_name: Field::String,
    path: Field::String,
    payment_pointer: Field::String,
    prx_account_uri: Field::String,
    prx_uri: Field::String,
    published_at: Field::DateTime,
    restrictions: Field::Text,
    serial_order: Field::Boolean,
    source_updated_at: Field::DateTime,
    source_url: Field::String,
    title: Field::Text,
    update_base: Field::DateTime,
    update_frequency: Field::Number,
    update_period: Field::String,
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
    title
    owner_email
    owner_name
    created_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    author_email
    author_name
    categories
    complete
    copyright
    deleted_at
    donation_url
    duration_padding
    episodes
    explicit
    feedburner_url
    guid
    itunes_block
    language
    link
    lock_version
    locked_until
    managing_editor_email
    managing_editor_name
    max_episodes
    owner_email
    owner_name
    path
    payment_pointer
    prx_account_uri
    prx_uri
    published_at
    restrictions
    serial_order
    source_updated_at
    source_url
    title
    update_base
    update_frequency
    update_period
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    author_email
    author_name
    categories
    complete
    copyright
    deleted_at
    donation_url
    duration_padding
    explicit
    feedburner_url
    guid
    itunes_block
    language
    link
    lock_version
    locked_until
    managing_editor_email
    managing_editor_name
    max_episodes
    owner_email
    owner_name
    path
    payment_pointer
    prx_account_uri
    prx_uri
    published_at
    restrictions
    serial_order
    source_updated_at
    source_url
    title
    update_base
    update_frequency
    update_period
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

  # Overwrite this method to customize how podcasts are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(podcast)
  #   "Podcast ##{podcast.id}"
  # end
end
