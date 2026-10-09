# frozen_string_literal: true

module Apple
  class ShowFeedBinding < ApplicationRecord
    ConnectionOption = Data.define(:label, :value)

    belongs_to :feed

    has_one :delegated_delivery_config,
      class_name: "Apple::DelegatedDeliveryConfig",
      foreign_key: :show_feed_binding_id,
      inverse_of: :show_feed_binding,
      dependent: :destroy

    alias_method :config, :delegated_delivery_config
    alias_method :config=, :delegated_delivery_config=

    validates :apple_show_id, presence: true, uniqueness: {message: "is already connected to another feed"}
    validates :feed_id, uniqueness: true
    validate :feed_must_support_apple
    before_destroy :protect_delegated_delivery, prepend: true
    after_destroy :clear_feed_sync_log

    scope :active, -> { joins(:feed).where(feeds: {deleted_at: nil}) }

    # Unassigned public-feed bindings, plus the delivery feed's own binding.
    def self.available_for_delivery(delivery_feed)
      candidates = active.left_outer_joins(:delegated_delivery_config)
        .where(feeds: {podcast_id: delivery_feed.podcast_id})
        .where(apple_configs: {feed_id: [nil, delivery_feed.id]})

      candidates.where(feeds: {private: false}).or(candidates.where(feed_id: delivery_feed.id)).includes(:feed)
    end

    def self.connect_existing(feed:, apple_show_id:)
      find_or_initialize_by(feed: feed).connect_existing(apple_show_id)
    end

    def connect_existing(apple_show_id)
      connect! if prepare_connection(apple_show_id)
      self
    end

    # Validates the connection and reads the show from Apple. Call it
    # outside a transaction so the Apple request holds no locks.
    def prepare_connection(apple_show_id)
      self.apple_show_id = apple_show_id
      valid?

      apple_key = feed.podcast&.apple_key
      if apple_key.nil?
        errors.add(:apple_key, "must be selected for the feed's podcast")
      elsif apple_key.account_id != feed.podcast.account_id
        errors.add(:apple_key, "must belong to the feed's PRX account")
      end
      return false if errors.any?

      verify_show_access
    end

    def connect!
      transaction do
        save!
        mirror_legacy_routing if feed.default?
      end
    end

    # Another feed's saved config that delivers through this show. Read from
    # the database, since this feed's own config may point here unsaved.
    def other_feed_config
      return unless persisted?

      Apple::DelegatedDeliveryConfig.where(show_feed_binding_id: id).where.not(feed_id: feed_id).includes(:feed).first
    end

    # Reload the config first, since the feed's save may have just removed
    # or repointed it.
    def disconnect
      association(:delegated_delivery_config).reset
      destroy
      self
    end

    private def verify_show_access
      Apple::Show.get_show(Apple::Api.from_key(feed.podcast.apple_key), apple_show_id)
      true
    rescue => error
      Rails.logger.error("Unable to connect Apple show feed binding", feed_id: feed_id, apple_show_id: apple_show_id, error: error)
      errors.add(:apple_show_id, "could not be read with the selected Apple credential")
      false
    end

    private def mirror_legacy_routing
      Apple::SyncLog.log!(feeder_id: feed_id, feeder_type: :feeds, external_id: apple_show_id)
      return unless delegated_delivery_config

      delegated_delivery_config.update!(key: feed.podcast.apple_key)
    end

    private def protect_delegated_delivery
      return if destroyed_by_association
      return unless delegated_delivery_config

      errors.add(:base, "cannot be removed while delegated-delivery feeds use it")
      throw :abort
    end

    private def clear_feed_sync_log
      Apple::SyncLog.feeds.where(feeder_id: feed_id).destroy_all
      feed.association(:apple_sync_log).reset
    end

    # Shows bound to other feeds are omitted, since a show connects to one feed.
    def self.connection_options(apple_key, feed:)
      return [] unless apple_key

      api = Apple::Api.from_key(apple_key)
      shows = Apple::Show.apple_shows_json(api) || []
      used_ids = where.not(feed: feed).pluck(:apple_show_id).to_set

      shows.filter_map do |show|
        next if show.dig("attributes", "publishingState") == "ARCHIVED"

        show_id = show["id"]
        next if show_id.blank? || used_ids.include?(show_id.to_s)

        title = show.dig("attributes", "title").presence || show_id
        ConnectionOption.new("#{title} — #{show_id}", show_id.to_s)
      end
    rescue => error
      Rails.logger.error("Unable to list Apple shows", apple_key_id: apple_key&.id, error: error)
      yield error if block_given?
      []
    end

    # Apple crawls a private feed through one of its tokens.
    def feed_must_support_apple
      if feed.is_a?(Feeds::MegaphoneFeed)
        errors.add(:feed, "cannot be a Megaphone feed")
      elsif feed&.private? && feed.active_apple_tokens.empty?
        errors.add(:feed, "must have a token when private")
      end
    end
  end
end
