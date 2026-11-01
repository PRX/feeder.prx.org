# frozen_string_literal: true

module Apple
  class DelegatedDeliveryConfig < ApplicationRecord
    self.table_name = "apple_configs"

    DEFAULT_TOKEN_LABEL = "Apple Subscriptions"

    belongs_to :feed
    belongs_to :show_feed_binding, class_name: "Apple::ShowFeedBinding", optional: false, inverse_of: :delegated_delivery_config

    validates :feed_id, uniqueness: true
    validates :show_feed_binding_id, uniqueness: true
    validate :show_feed_binding_belongs_to_podcast
    validate :show_feed_binding_is_public_or_own

    after_create :ensure_private_feed_token

    alias_method :private_feed, :feed

    def apple_key
      show_feed_binding&.feed&.podcast&.apple_key
    end

    def public_feed
      show_feed_binding&.feed
    end

    def apple_show_id
      show_feed_binding&.apple_show_id
    end

    def publish_to_apple?
      !!apple_key&.valid? && publish_enabled?
    end

    def build_publisher
      Apple::Publisher.from_delegated_delivery_config(self)
    end

    def build_show
      Apple::Show.from_delegated_delivery_config(self)
    end

    private

    def ensure_private_feed_token
      return unless feed.private?
      return if feed.tokens.any? { |token| !token.marked_for_destruction? && !token.destroyed? }

      feed.tokens.create!(label: DEFAULT_TOKEN_LABEL)
    end

    def show_feed_binding_belongs_to_podcast
      return unless feed && show_feed_binding
      return if feed.podcast_id == show_feed_binding.feed&.podcast_id

      errors.add(:show_feed_binding, "must belong to the configured feed's podcast")
    end

    def show_feed_binding_is_public_or_own
      bound_feed = show_feed_binding&.feed
      return if bound_feed.nil? || bound_feed.public? || bound_feed == feed

      errors.add(:show_feed_binding, "must belong to a public feed or this feed")
    end
  end
end
