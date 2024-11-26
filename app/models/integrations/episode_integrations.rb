require "active_support/concern"

module Integrations::EpisodeIntegrations
  extend ActiveSupport::Concern

  included do
    has_many :episode_delivery_statuses, -> { order(created_at: :desc) }, class_name: "Integrations::EpisodeDeliveryStatus"
  end

  def episode_delivery_status(integration)
    episode_delivery_statuses.order(created_at: :desc).send(integration.intern).first
  end

  def update_episode_delivery_status(integration, attrs)
    Integrations::EpisodeDeliveryStatus.update_status(integration, self, attrs)
  end
end
