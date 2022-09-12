# frozen_string_literal: true

module Apple
  class PodcastContainer < ActiveRecord::Base
    serialize :api_response, JSON

    belongs_to :episode, class_name: "::Episode"

    def podcast_deliveries_url
      api_response.dig("data", "relationships", "podcastDeliveries", "links", "self")
    end
  end
end
