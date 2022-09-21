# frozen_string_literal: true

require "uri"

module Apple
  class UploadOperation
    attr_reader :episode, :api, :operation

    def initialize(episode, operation_fragment)
      @episode = episode
      @api = Apple::Api.from_env
      @operation = operation_fragment
    end

    def head_file_size_bridge_params
      {
        episode_id: episode.apple_id,
        api_url: episode.feeder_episode.enclosure_url,
        api_parameters: {},
      }
    end

    def upload_operation_patch_parameters
      podcast_delivery = episode.podcast_container.podcast_delivery
      {
        request_metadata: {
          podcast_delivery_id: episode.podcast_container.podcast_delivery.external_id,
          episode_id: episode.apple_id,
        },
        api_url: api.join_url("podcastDeliveryFiles").to_s,
        api_parameters: podcast_delivery_file_create_parameters(podcast_delivery, filename, num_bytes)
      }
    end

    def upload_operation_bridge_parameters; end
  end
end
