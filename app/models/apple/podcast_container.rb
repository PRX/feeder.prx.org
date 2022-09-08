# frozen_string_literal: true

module Apple
  class PodcastContainer < ActiveRecord::Base
    serialize :api_response, JSON

    belongs_to :episode, class_name: "::Episode"

    def apple_resp
      api_response["podcast_container_response"]
    end

    def podcast_deliveries_url
      apple_resp.dig("data", "relationships", "podcastDeliveries", "links", "self")
    end
  end
end
