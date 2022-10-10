# frozen_string_literal: true

require "uri"

module Apple
  class UploadOperation
    attr_reader :delivery_file, :api, :operation

    def initialize(delivery_file, operation_fragment)
      @delivery_file = delivery_file
      @api = Apple::Api.from_env
      @operation = operation_fragment
    end

    def self.execute_upload_operations(api, episodes)
      delivery_files = Apple::PodcastDeliveryFile.where(episode_id: episodes.map(&:feeder_id), uploaded: false)

      operation_bridge_params =
        delivery_files.map do |df|
          df.upload_operations.map(&:upload_operation_patch_parameters)
        end.flatten

      res = api.bridge_remote("executeUploadOperations", operation_bridge_params)

      api.unwrap_response(res)
    end

    def podcast_delivery
      delivery_file.podcast_delivery
    end

    def upload_operation_patch_parameters
      {
        request_metadata: {
          podcast_delivery_file_id: delivery_file.id,
        },
        api_url: delivery_file.episode.enclosure_url,
        api_parameters: operation
      }
    end
  end
end
