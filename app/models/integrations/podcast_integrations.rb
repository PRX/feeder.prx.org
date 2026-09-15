require "active_support/concern"

module Integrations::PodcastIntegrations
  extend ActiveSupport::Concern

  # included do
  # end

  def publish_to_integration?(integration)
    feeds.any? { |feed| feed.integration_type == integration && feed.publish_integration? }
  end
end
