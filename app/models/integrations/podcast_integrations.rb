require "active_support/concern"

module Integrations::PodcastIntegrations
  extend ActiveSupport::Concern

  # included do
  # end

  def publish_to_integration?(integration)
    # see if there is an integration
    feeds.any? { |f| f.integration_type == integration && f.publish_integration? }
  end
end
