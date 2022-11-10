# frozen_string_literal: true

module Apple
  class PodcastDeliveryFile < ActiveRecord::Base
    include Apple::ApiResponse

    serialize :api_response, JSON

    belongs_to :podcast_delivery
    belongs_to :episode, class_name: "::Episode"

    delegate :apple_episode_id, to: :podcast_delivery

    def self.wait_for_delivery_files(api, pdfs)
      wait_for_delivery(api, pdfs)
      wait_for_processing(api, pdfs)
    end

    def self.wait_for_processing(api, pdfs)
      wait_for(api, pdfs) do |updated_pdfs|
        updated_pdfs.all? { |pdf| pdf.processed? || pdf.processed_errors? }
      end
    end

    def self.wait_for_delivery(api, pdfs)
      wait_for(api, pdfs) do |updated_pdfs|
        updated_pdfs.all?(&:delivered?)
      end
    end

    def self.wait_for(api, pdfs)
      t_beg = Time.now.utc
      loop_res =
        loop do
          break false if Time.now.utc - t_beg > 5.minutes
          break true if yield(pdfs)

          get_and_update_api_response(api, pdfs)
          sleep(2)
        end

      pdfs.map(&:save!)

      loop_res
    end

    def self.get_and_update_api_response(api, pdfs)
      unwrapped = get_podcast_delivery_files(api, pdfs)

      pdfs.each do |pdf|
        matched = unwrapped.detect { |r| r["request_metadata"]["podcast_delivery_file_id"] == pdf.id }
        raise "Missing response for podcast delivery file" unless matched.present?

        pdf.api_response = matched
      end
    end

    def self.mark_uploaded(api, pdfs)
      updated_pdfs = []

      bridge_params = pdfs.map { |pdf| mark_uploaded_delivery_file_bridge_params(api, pdf) }

      api.bridge_remote_and_retry!("updateDeliveryFiles", bridge_params).map do |row|
        pd_id = row["request_metadata"]["podcast_delivery_file_id"]
        Apple::PodcastDeliveryFile.find(pd_id).update!(api_response: row, uploaded: true)
      end
    end

    def self.get_podcast_delivery_files(api, pdfs)
      bridge_params = pdfs.map { |pdf| get_delivery_file_bridge_params(api, pdf) }
      api.bridge_remote_and_retry!("getDeliveryFiles", bridge_params)
    end

    def self.create_podcast_delivery_files(api, episodes)
      return [] if episodes.empty?

      episodes_needing_delivery_files =
        episodes.reject { |ep| ep.podcast_container&.podcast_delivery&.podcast_delivery_file.present? }

      podcast_deliveries = Apple::PodcastDelivery.where(episode_id: episodes_needing_delivery_files.map(&:feeder_id))
      podcast_deliveries_by_id = podcast_deliveries.map { |p| [p.id, p] }.to_h

      new_delivery_files =
        api.bridge_remote_and_retry!("createDeliveryFiles",
                                     podcast_deliveries.map do |d|
                                       create_delivery_file_bridge_params(api, d)
                                     end)
      new_delivery_files.map do |row|
        pd = podcast_deliveries_by_id.fetch(row["request_metadata"]["podcast_delivery_id"])
        create_podcast_delivery_file(pd, row)
      end
    end

    def self.get_delivery_file_bridge_params(api, podcast_delivery_file)
      {
        request_metadata: {
          podcast_delivery_file_id: podcast_delivery_file.id,
          episode_id: podcast_delivery_file.podcast_delivery.episode_id
        },
        api_url: api.join_url("podcastDeliveryFiles/" + podcast_delivery_file.apple_id).to_s
      }
    end

    def self.mark_uploaded_delivery_file_bridge_params(api, podcast_delivery_file)
      {
        request_metadata: {
          podcast_delivery_file_id: podcast_delivery_file.id,
          episode_id: podcast_delivery_file.podcast_delivery.episode_id
        },
        api_url: api.join_url("podcastDeliveryFiles/" + podcast_delivery_file.apple_id).to_s,
        api_parameters: podcast_delivery_file.mark_uploaded_parameters
      }
    end

    def self.create_delivery_file_bridge_params(api, podcast_delivery)
      {
        request_metadata: {
          podcast_delivery_id: podcast_delivery.id,
          episode_id: podcast_delivery.episode_id
        },
        api_url: api.join_url("podcastDeliveryFiles").to_s,
        api_parameters: podcast_delivery_file_create_parameters(podcast_delivery)
      }
    end

    def self.podcast_delivery_file_create_parameters(podcast_delivery)
      podcast_container = podcast_delivery.podcast_container

      { "data": {
        "type": "podcastDeliveryFiles",
        "apple_attributes": {
          "assetType": "ASSET",
          "assetRole": "PodcastSourceAudio",
          "fileSize": podcast_container.source_size,
          "fileName": podcast_container.source_filename,
          "uti": "public.json"
        },
        "relationships": {
          "podcastDelivery": {
            "data": {
              "type": "podcastDeliveries",
              "id": podcast_delivery.external_id
            }
          }
        }
      } }
    end

    def self.create_podcast_delivery_file(podcast_delivery, row)
      external_id = row.dig("api_response", "val", "data", "id")
      pc = Apple::PodcastDeliveryFile.create!(episode_id: podcast_delivery.episode_id,
                                              external_id: external_id,
                                              podcast_delivery_id: podcast_delivery.id,
                                              api_response: row)

      SyncLog.create!(feeder_id: pc.id, feeder_type: :podcast_delivery_files, external_id: external_id)
    end

    def mark_uploaded_parameters
      {
        data: {
          id: apple_id,
          type: "podcastDeliveryFiles",
          apple_attributes: {
            uploaded: true
          }
        }
      }
    end

    def upload_operations
      apple_apple_attributes["uploadOperations"].map do |operation_fragment|
        Apple::UploadOperation.new(self, operation_fragment)
      end
    end

    def apple_complete?
      delivered? && processed?
    end

    def delivered?
      return false unless asset_delivery_state.present?

      asset_delivery_state["state"] == "COMPLETE" ||
        asset_delivery_state["state"] == "COMPLETED"
    end

    def processed_errors?
      return false unless asset_processing_state.present?

      apple_attributes["assetProcessingState"]["state"] == "VALIDATION_FAILED"
    end

    def processed?
      return false unless asset_processing_state.present?

      asset_processing_state["state"] == "COMPLETE" ||
        apple_attributes["assetProcessingState"]["state"] == "COMPLETED"
    end

    def asset_processing_state
      apple_attributes["assetProcessingState"]
    end

    def asset_delivery_state
      apple_attributes["assetDeliveryState"]
    end

    def apple_id
      apple_data['id']
    end

  end
end
