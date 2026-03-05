# frozen_string_literal: true

module Apple
  class UploadOperation
    attr_reader :delivery_file, :api, :operation

    def initialize(delivery_file:, operation_fragment:)
      @delivery_file = delivery_file
      @operation = operation_fragment
    end

    def self.execute_upload_operations(api, media_infos)
      media_infos_by_episode_id = media_infos.index_by { |mi| mi.episode.feeder_id }

      delivery_files = Apple::PodcastDeliveryFile.where(
        episode_id: media_infos_by_episode_id.keys,
        upload_operations_complete: false
      )

      operation_bridge_params =
        delivery_files.map do |df|
          media_info = media_infos_by_episode_id.fetch(df.episode_id)
          df.upload_operations.map { |op| op.upload_operation_patch_parameters(media_info: media_info) }
        end.flatten

      res = do_upload(api, operation_bridge_params)

      Apple::PodcastDeliveryFile.where(id: delivery_files.map(&:id)).update_all(upload_operations_complete: true)

      res.flatten
    end

    def self.do_upload(api, operation_bridge_params)
      res =
        if api.development_bridge_url?
          serial_upload(api, operation_bridge_params)
        else
          parallel_upload(api, operation_bridge_params)
        end

      res.flatten
    end

    def self.serial_upload(api, operation_bridge_params)
      operation_bridge_params.map do |op|
        api.bridge_remote_and_retry!("executeUploadOperations", [op])
      end
    end

    def self.parallel_upload(api, operation_bridge_params)
      num_threads = 10
      chunk_size = operation_bridge_params.size / num_threads
      chunk_size = [chunk_size, 1].max

      chunked_slices = operation_bridge_params.each_slice(chunk_size).to_a

      caller_log_tags = Rails.logger.formatter.current_tags.dup
      Parallel.map(chunked_slices, in_threads: num_threads) do |ops|
        Rails.logger.tagged(caller_log_tags) do
          api.bridge_remote_and_retry!("executeUploadOperations", ops, batch_size: 1)
        end
      end
    end

    def podcast_delivery
      delivery_file.podcast_delivery
    end

    def upload_operation_patch_parameters(media_info:)
      source_url = media_info.source_url

      {
        request_metadata: {
          podcast_delivery_file_id: delivery_file.id
        },
        api_url: source_url,
        api_parameters: operation
      }
    end
  end
end
