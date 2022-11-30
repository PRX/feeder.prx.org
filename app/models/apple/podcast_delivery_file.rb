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
        Rails.logger.info("Probing for file processing")
        updated_pdfs.all? { |pdf| pdf.processed? || pdf.processed_errors? }
      end
    end

    def self.wait_for_delivery(api, pdfs)
      wait_for(api, pdfs) do |updated_pdfs|
        Rails.logger.info("Probing for file delivery")
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
      bridge_params = pdfs.map { |pdf| mark_uploaded_delivery_file_bridge_params(api, pdf) }

      api.bridge_remote_and_retry!("updateDeliveryFiles", bridge_params).map do |row|
        pd_id = row["request_metadata"]["podcast_delivery_file_id"]
        Apple::PodcastDeliveryFile.find(pd_id).update!(api_response: row, uploaded: true)
      end
    end

    def self.create_podcast_delivery_files(api, episodes)
      return [] if episodes.empty?

      # TODO: handle multiple containers
      episodes_needing_delivery_files =
        episodes.reject { |ep| ep.podcast_delivery_files.present? }

      podcast_deliveries = Apple::PodcastDelivery.where(episode_id: episodes_needing_delivery_files.map(&:feeder_id))

      result =
        api.bridge_remote_and_retry!("createPodcastDeliveryFiles",
                                     podcast_deliveries.map { |pd| create_delivery_file_bridge_params(api, pd) })

      join_on("podcast_delivery_id", podcast_deliveries, result).each do |(podcast_delivery, row)|
        upsert_podcast_delivery_file(podcast_delivery, row)
      end
    end

    def self.update_podcast_delivery_files_state(api, episodes)
      results = get_podcast_delivery_files_via_deliveries(api, episodes)

      join_on_apple_episode_id(episodes, results).map do |(episode, delivery_file_row)|
        upsert_podcast_delivery_file(episode, delivery_file_row)
      end
    end

    def self.get_podcast_delivery_files(api, pdfs)
      bridge_params = pdfs.map { |pdf| get_delivery_file_bridge_params(api, pdf) }
      api.bridge_remote_and_retry!("getPodcastDeliveryFiles", bridge_params)
    end

    def self.get_podcast_delivery_files_via_deliveries(api, episodes)
      # Fetch the podcast delivery files from the delivery side of the api
      podcast_containers = episodes.map(&:podcast_container)

      # Assume that the delivery remote/local state is synced at this point
      podcast_deliveries =
        episodes.
        map(&:feeder_episode).
        map(&:apple_podcast_deliveries).
        flatten

      delivery_files_response =
        api.bridge_remote_and_retry!("getPodcastDeliveryFiles",
                                     get_delivery_podcast_delivery_files_bridge_params(podcast_deliveries))

      # Rather than mangling and persisting the enumerated view of the delivery files
      # Instead, re-fetch the podcast delivery file from the non-list podcast delivery file resource
      formatted_bridge_params = join_on_apple_episode_id(podcast_deliveries, delivery_files_response).map do |(pd, row)|
        # get the urls to fetch delivery files belonging to this podcast delivery (pd)
        get_urls_for_delivery_podcast_delivery_files(api, row).map do |url|
          get_delivery_podcast_delivery_files_bridge_param(pd.apple_episode_id, pd.id, url)
        end
      end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!("getPodcastDeliveryFiles",
                                   formatted_bridge_params)
    end

    def self.get_urls_for_delivery_podcast_delivery_files(api, delivery_podcast_delivery_files_json)
      delivery_podcast_delivery_files_json["api_response"]["val"]["data"].map do |podcast_delivery_file_data|
        api.join_url("podcastDeliveryFiles/#{podcast_delivery_file_data['id']}").to_s
      end
    end

    # Query from the podcast delivery side of the api
    def self.get_delivery_podcast_delivery_files_bridge_params(podcast_deliveries)
      podcast_deliveries.map do |delivery|
        get_delivery_podcast_delivery_files_bridge_param(delivery.apple_episode_id,
                                                         delivery.id,
                                                         delivery.podcast_delivery_files_url)
      end
    end

    # Query from the podcast delivery side of the api
    def self.get_delivery_podcast_delivery_files_bridge_param(apple_episode_id, podcast_delivery_id, api_url)
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_delivery_id: podcast_delivery_id
        },
        api_url: api_url,
        api_parameters: {}
      }
    end

    def self.get_delivery_file_bridge_params(api, podcast_delivery_file)
      {
        request_metadata: {
          podcast_delivery_file_id: podcast_delivery_file.id,
          podcast_delivery_id: podcast_delivery_file.podcast_delivery.id
        },
        api_url: api.join_url("podcastDeliveryFiles/" + podcast_delivery_file.apple_id).to_s
      }
    end

    def self.mark_uploaded_delivery_file_bridge_params(api, podcast_delivery_file)
      {
        request_metadata: {
          podcast_delivery_file_id: podcast_delivery_file.id,
          podcast_delivery_id: podcast_delivery_file.podcast_delivery.id
        },
        api_url: api.join_url("podcastDeliveryFiles/" + podcast_delivery_file.apple_id).to_s,
        api_parameters: podcast_delivery_file.mark_uploaded_parameters
      }
    end

    def self.create_delivery_file_bridge_params(api, podcast_delivery)
      {
        request_metadata: {
          podcast_delivery_id: podcast_delivery.id
        },
        api_url: api.join_url("podcastDeliveryFiles").to_s,
        api_parameters: podcast_delivery_file_create_parameters(podcast_delivery)
      }
    end

    def self.podcast_delivery_file_create_parameters(podcast_delivery)
      podcast_container = podcast_delivery.podcast_container

      { "data": {
        "type": "podcastDeliveryFiles",
        "attributes": {
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

    def self.upsert_podcast_delivery_file(episode, row)
      external_id = row.dig("api_response", "val", "data", "id")
      podcast_delivery_id = row.dig("request_metadata", "podcast_delivery_id")

      pdf =
        if delivery_file = where(episode_id: episode.feeder_id,
                                 external_id: external_id,
                                 podcast_delivery_id: podcast_delivery_id).first

          Rails.logger.info("Updating local podcast delivery file w/ Apple id #{external_id} for episode #{episode.feeder_id}")
          delivery_file.update(api_response: row, updated_at: Time.now.utc)
          delivery_file
        else
          Rails.logger.info("Creating local podcast delivery file w/ Apple id #{external_id} for episode #{episode.feeder_id}")
          Apple::PodcastDeliveryFile.create!(episode_id: episode.feeder_id,
                                             external_id: external_id,
                                             podcast_delivery_id: podcast_delivery_id,
                                             api_response: row)

        end

      SyncLog.create!(feeder_id: pdf.id, feeder_type: :podcast_delivery_files, external_id: external_id)

      pdf
    end

    def mark_uploaded_parameters
      {
        data: {
          id: apple_id,
          type: "podcastDeliveryFiles",
          attributes: {
            uploaded: true
          }
        }
      }
    end

    def upload_operations
      (apple_attributes["uploadOperations"] || []).map do |operation_fragment|
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
  end
end
