require "active_support/concern"

module Integrations::EpisodeIntegrations
  extend ActiveSupport::Concern

  included do
    has_many :episode_delivery_statuses, -> { order(created_at: :desc) }, class_name: "Integrations::EpisodeDeliveryStatus"
  end

  def publish_to_integration?(integration)
    podcast.publish_to_integration?(integration)
  end

  # Enabled integration feeds this episode is actually delivered through. A
  # podcast can have several, so membership is resolved per episode.
  def integration_feeds(integration)
    podcast.feeds.select do |feed|
      feed.integration_types.include?(integration) &&
        feed.publish_integration?(integration) &&
        feed.integration_episode?(self, integration)
    end
  end
end
