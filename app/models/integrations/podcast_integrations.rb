require "active_support/concern"

module Integrations::PodcastIntegrations
  extend ActiveSupport::Concern

  def publish_to_integration?(integration)
    feeds.any? { |f| f.integration_types.include?(integration) && f.publish_integration?(integration) }
  end
end
