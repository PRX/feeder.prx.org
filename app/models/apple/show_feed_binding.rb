# frozen_string_literal: true

module Apple
  class ShowFeedBinding < ApplicationRecord
    ConnectionOption = Data.define(:label, :value)

    belongs_to :feed

    has_one :delegated_delivery_config,
      class_name: "Apple::DelegatedDeliveryConfig",
      foreign_key: :show_feed_binding_id,
      inverse_of: :show_feed_binding,
      dependent: :nullify

    alias_method :config, :delegated_delivery_config
    alias_method :config=, :delegated_delivery_config=

    validates :apple_show_id, presence: true
    validates :feed_id, uniqueness: true
    validate :feed_must_be_public

    scope :active, -> { joins(:feed).where(feeds: {deleted_at: nil}) }

    def self.connect_existing(feed:, apple_key:, apple_show_id:)
      binding = find_or_initialize_by(feed: feed)
      binding.apple_show_id = apple_show_id
      binding.valid?
      unless feed.podcast && apple_key&.account_id == feed.podcast.account_id
        binding.errors.add(:apple_key, "must belong to the feed's PRX account")
      end
      return binding if binding.errors.any?

      Apple::Show.from_show_feed_binding(binding, apple_key: apple_key).get_show
      transaction do
        feed.podcast.update!(apple_key: apple_key)
        binding.save!
      end
      binding
    rescue => error
      Rails.logger.error("Unable to connect Apple show feed binding", feed_id: feed.id, apple_show_id: apple_show_id, error: error)
      binding ||= new(feed: feed, apple_show_id: apple_show_id)
      binding.errors.add(:apple_show_id, "could not be read with the selected Apple credential")
      binding
    end

    def self.connection_options(keys)
      keys.flat_map do |key|
        api = Apple::Api.from_apple_key(key)
        shows = Apple::Show.apple_shows_json(api) || []

        shows.filter_map do |show|
          next if show.dig("attributes", "publishingState") == "ARCHIVED"

          show_id = show["id"]
          next if show_id.blank?

          title = show.dig("attributes", "title").presence || show_id
          key_label = key.key_id.to_s.last(4)
          ConnectionOption.new("#{title} — #{show_id} · Key …#{key_label}", connection_token(key.id, show_id))
        end
      rescue => error
        Rails.logger.error("Unable to list Apple shows", apple_key_id: key.id, error: error)
        []
      end
    end

    def self.connection_token(apple_key_id, apple_show_id)
      "#{apple_key_id}:#{apple_show_id}"
    end

    def self.parse_connection_token(token)
      apple_key_id, apple_show_id = token.to_s.split(":", 2)
      return if apple_key_id.blank? || apple_show_id.blank?

      [apple_key_id, apple_show_id]
    end

    def connection_token
      self.class.connection_token(feed&.podcast&.apple_key_id, apple_show_id)
    end

    def feed_must_be_public
      if feed && !feed.public?
        errors.add(:feed, "must be a public feed")
      end
    end
  end
end
