# frozen_string_literal: true

module Apple
  class DelegatedDeliveryConfig < ApplicationRecord
    self.table_name = "apple_configs"

    ROUTING_SOURCES = {
      "legacy" => :legacy,
      "show_feed_binding" => :show_feed_binding
    }.freeze

    belongs_to :feed
    belongs_to :key, class_name: "Apple::Key", optional: true, validate: true, autosave: true
    # Nullable only during routing migration; this is required at cutover.
    belongs_to :show_feed_binding, class_name: "Apple::ShowFeedBinding", optional: true, inverse_of: :delegated_delivery_config

    validates :show_feed_binding_id, uniqueness: true, allow_nil: true
    validate :podcast_has_one_delegated_delivery_config
    validate :not_default_feed
    validate :show_feed_binding_matches_podcast
    validate :key_belongs_to_podcast_account

    # backwards-compatible associations
    delegate :podcast, to: :feed, allow_nil: true
    delegate :id, :title, to: :podcast, prefix: true, allow_nil: true
    alias_method :private_feed, :feed

    accepts_nested_attributes_for :key

    before_validation :assign_key_account

    def self.routing_source
      source = ENV.fetch("APPLE_ROUTING_SOURCE", "legacy")
      ROUTING_SOURCES.fetch(source) do
        raise ArgumentError,
          "Unsupported APPLE_ROUTING_SOURCE=#{source.inspect}; expected one of #{ROUTING_SOURCES.keys.join(", ")}"
      end
    end

    def routing_source
      self.class.routing_source
    end

    def routing_key
      case routing_source
      when :legacy
        key
      when :show_feed_binding
        show_feed_binding&.feed&.podcast&.apple_key
      end
    end

    def public_feed
      case routing_source
      when :legacy
        legacy_public_feed
      when :show_feed_binding
        show_feed_binding&.feed
      end
    end

    def apple_show_id
      case routing_source
      when :legacy
        legacy_apple_show_id
      when :show_feed_binding
        show_feed_binding&.apple_show_id
      end
    end

    def legacy_public_feed
      podcast&.public_feed
    end

    def legacy_apple_show_id
      legacy_public_feed&.apple_sync_log&.external_id.presence || private_feed&.apple_show_id.presence
    end

    def not_default_feed
      if feed&.default?
        errors.add(:feed, "cannot use default feed")
      end
    end

    def podcast_has_one_delegated_delivery_config
      all_feeds = Feed.where(podcast_id: feed.podcast_id).pluck(:id)
      if Apple::DelegatedDeliveryConfig.where(feed_id: all_feeds).where.not(id: id).any?
        errors.add(:feed, "podcast already has a delegated delivery config")
      end
    end

    def show_feed_binding_matches_podcast
      return unless feed && show_feed_binding&.feed
      return if feed.podcast_id == show_feed_binding.feed.podcast_id

      errors.add(:show_feed_binding, "must belong to the same podcast as feed")
    end

    def key_belongs_to_podcast_account
      return unless key && podcast
      return if key.account_id == podcast.account_id

      errors.add(:key, "must belong to the podcast's PRX account")
    end

    def assign_key_account
      key.account_id = podcast&.account_id if key&.new_record?
    end

    def publish_to_apple?
      !!routing_key&.valid? && publish_enabled?
    end

    def build_publisher
      Apple::Publisher.from_delegated_delivery_config(self)
    end

    def build_show
      Apple::Show.from_delegated_delivery_config(self)
    end
  end
end
