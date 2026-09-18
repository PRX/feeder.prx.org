require "active_support/concern"

module Integrations::EpisodeIntegrations
  extend ActiveSupport::Concern

  included do
    has_many :episode_delivery_statuses, -> { order(created_at: :desc) }, class_name: "Integrations::EpisodeDeliveryStatus"
  end

  def publish_to_integration?(integration)
    podcast.publish_to_integration?(integration)
  end

  def integration_feed_episode?(integration)
    integration_feeds(integration).any?
  end

  # Enabled integration feeds this episode is actually delivered through. A
  # podcast can have several, so membership is resolved per episode.
  def integration_feeds(integration)
    podcast.feeds.select do |feed|
      case integration
      when :apple
        feed.publish_to_apple? && feed.apple_episode?(self)
      when :megaphone
        feed.is_a?(Feeds::MegaphoneFeed) && feed.publish_to_megaphone? && feed.feed_episode?(self)
      else
        false
      end
    end
  end

  def integration_feed(integration)
    feeds = integration_feeds(integration)
    feeds.one? ? feeds.first : nil
  end
end
