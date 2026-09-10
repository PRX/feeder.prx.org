# frozen_string_literal: true

module Apple
  class ShowFeedBinding < ApplicationRecord
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

    def feed_must_be_public
      if feed && !feed.public?
        errors.add(:feed, "must be a public feed")
      end
    end
  end
end
