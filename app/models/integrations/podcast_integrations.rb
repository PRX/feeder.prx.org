require "active_support/concern"

module Integrations::PodcastIntegrations
  extend ActiveSupport::Concern

  def publish_to_integration?(integration)
    case integration
    when :apple
      feeds.any?(&:publish_to_apple?)
    when :megaphone
      feeds.any? { |feed| feed.is_a?(Feeds::MegaphoneFeed) && feed.publish_to_megaphone? }
    else
      false
    end
  end
end
