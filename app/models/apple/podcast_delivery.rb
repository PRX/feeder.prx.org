# frozen_string_literal: true

module Apple
  class PodcastDelivery < ActiveRecord::Base
    serialize :api_response, JSON

    belongs_to :episode, class_name: "::Episode"

    enum status: {
      awaiting_upload: "AWAITING_UPLOAD",
      completed: "COMPLETED",
      failed: "FAILED",
    }
  end

  def self.create_podcast_delivery_bridge_params(episodes_to_sync)
    episodes_to_sync.map do |ep|
      {
        episode_id: ep.id,
        api_url: api.join_url("podcastDeliveries").to_s,
        api_parameters: podcast_container_create_parameters(ep)
      }
    end
  end

  def self.podcast_delivery_create_parameters(ep)
    {
      data: {
        type: "podcastDeliveries",
        relationships: {
          podcastContainer: {
            data: {
              type: "podcastContainers",
              id: ep.podcast_container.external_id
            }
          }
        }
      }
    }
  end
end
