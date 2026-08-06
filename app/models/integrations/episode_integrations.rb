require "active_support/concern"

module Integrations::EpisodeIntegrations
  extend ActiveSupport::Concern

  included do
    has_many :episode_delivery_statuses, -> { order(created_at: :desc) }, class_name: "Integrations::EpisodeDeliveryStatus"
  end

  def integration_episode(integration)
    integration_episode_method = "#{integration}_episode"
    if respond_to?(integration_episode_method)
      send(integration_episode_method)
    end
  end

  def publish_to_integration?(integration)
    # see if there is an integration
    podcast.feeds.any? { |f| f.integration_type == integration && f.publish_integration? }
  end

  def integration_feed_episode?(integration)
    feed = integration_feed(integration)
    publish_to_integration?(integration) && feed&.integration_episode?(self)
  end

  def integration_feed(integration)
    feeds = podcast.feeds.select { |feed| feed.integration_type == integration }
    feeds.one? ? feeds.first : nil
  end

  def integration_error_state?(integration)
    integration_episode(integration)&.error_state? || false
  end
end
