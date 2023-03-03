# frozen_string_literal: true

module Apple
  class PodcastDeliveryFile < ActiveRecord::Base
    include Apple::ApiResponse
    include Apple::ApiWaiting

    serialize :api_response, JSON

    belongs_to :podcast_delivery
    has_one :podcast_container, through: :podcast_delivery
    belongs_to :episode, class_name: "::Episode"

    delegate :apple_episode_id, to: :podcast_delivery

    PODCAST_DELIVERY_ID_ATTR = "podcast_delivery_id"

    def self.wait_for_delivery_files(api, pdfs)
      wait_for_delivery(api, pdfs)
      wait_for_processing(api, pdfs)
    end

    def self.wait_for_processing(api, pdfs)
      wait_for(pdfs) do |remaining_pdfs|
        Rails.logger.info("Probing for file processing")
        updated_pdfs = get_and_update_api_response(api, remaining_pdfs)

        finished = updated_pdfs.group_by { |pdf| pdf.processed? || pdf.processed_errors? }
        (finished[true] || []).map(&:save!)
        (finished[false] || [])
      end
    end

    def self.wait_for_delivery(api, pdfs)
      wait_for(pdfs) do |remaining_pdfs|
        Rails.logger.info("Probing for file delivery")
        updated_pdfs = get_and_update_api_response(api, pdfs)

        finished = updated_pdfs.group_by(&:delivered?)
        (finished[true] || []).map(&:save!)
        (finished[false] || [])
      end
    end

    def self.get_and_update_api_response(api, pdfs)
      unwrapped = get_podcast_delivery_files(api, pdfs)

      pdfs.each do |pdf|
        matched = unwrapped.detect { |r| r["request_metadata"]["podcast_delivery_id"] == pdf.podcast_delivery_id }
        raise "Missing response for podcast delivery file" unless matched.present?

        pdf.api_response = matched
      end
    end

    def self.mark_uploaded(api, pdfs)
      # These still need to be marked as uploaded
      pdfs = pdfs.reject { |pdf| pdf.api_marked_as_uploaded? }

      bridge_params = pdfs.map { |pdf| mark_uploaded_delivery_file_bridge_params(api, pdf) }

      # return results alongside potential errors
      (episode_bridge_results, errs) = api.bridge_remote_and_retry("updateDeliveryFiles", bridge_params)

      episode_bridge_results.map do |row|
        pd_id = row["request_metadata"]["podcast_delivery_file_id"]
        Apple::PodcastDeliveryFile.find(pd_id).update!(api_response: row, api_marked_as_uploaded: true)
      end

      api.raise_bridge_api_error(errs) if errs.present?

      episode_bridge_results
    end

    def self.create_podcast_delivery_files(api, episodes)
      return [] if episodes.empty?

      podcast_containers = episodes.map(&:podcast_container)
      podcast_deliveries = podcast_containers.map do |pc|
        raise("Missing podcast deliveries") if pc.podcast_deliveries.empty?

        pc.podcast_deliveries
      end

      podcast_deliveries = podcast_deliveries.flatten
      # filter for only the podcast deliveries that have missing podcast delivery files
      podcast_deliveries = podcast_deliveries.select { |pd| pd.podcast_delivery_files.empty? }

      result =
        api.bridge_remote_and_retry!("createPodcastDeliveryFiles",
          podcast_deliveries.map { |pd| create_delivery_file_bridge_params(api, pd) })

      join_on(PODCAST_DELIVERY_ID_ATTR, podcast_deliveries, result).each do |(podcast_delivery, row)|
        upsert_podcast_delivery_file(podcast_delivery, row)
      end
    end

    def self.poll_podcast_delivery_files_state(api, episodes)
      # Assume that the delivery remote/local state is synced at this point
      podcast_deliveries =
        episodes
          .map(&:feeder_episode)
          .map(&:apple_podcast_deliveries)
          .flatten

      results = get_podcast_delivery_files_via_deliveries(api, podcast_deliveries)

      join_on(PODCAST_DELIVERY_ID_ATTR, podcast_deliveries, results).map do |(podcast_delivery, delivery_file_row)|
        upsert_podcast_delivery_file(podcast_delivery, delivery_file_row)
      end
    end

    def self.get_podcast_delivery_files(api, pdfs)
      bridge_params = pdfs.map do |pdf|
        api_url = api.join_url("podcastDeliveryFiles/#{pdf.apple_id}").to_s
        get_delivery_file_bridge_params(pdf.apple_episode_id, pdf.podcast_delivery_id, api_url)
      end
      api.bridge_remote_and_retry!("getPodcastDeliveryFiles", bridge_params)
    end

    def self.get_podcast_delivery_files_via_deliveries(api, podcast_deliveries)
      delivery_files_response =
        api.bridge_remote_and_retry!("getPodcastDeliveryFiles",
          get_delivery_podcast_delivery_files_bridge_params(podcast_deliveries))

      # Rather than mangling and persisting the enumerated view of the delivery files from the podcast delivery
      # Instead, re-fetch the podcast delivery file from the non-list podcast delivery file resource
      formatted_bridge_params = join_on_apple_episode_id(podcast_deliveries, delivery_files_response).map do |(pd, row)|
        # get the urls to fetch delivery files belonging to this podcast delivery (pd)
        get_urls_for_delivery_podcast_delivery_files(api, row).map do |url|
          get_delivery_file_bridge_params(pd.apple_episode_id, pd.id, url)
        end
      end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!("getPodcastDeliveryFiles",
        formatted_bridge_params)
    end

    def self.get_urls_for_delivery_podcast_delivery_files(api, delivery_podcast_delivery_files_json)
      delivery_podcast_delivery_files_json["api_response"]["val"]["data"].map do |podcast_delivery_file_data|
        api.join_url("podcastDeliveryFiles/#{podcast_delivery_file_data["id"]}").to_s
      end
    end

    # Map across the podcast deliveries and get the bridge params for each
    # delivery file via the podcast delivery api endpoint.
    def self.get_delivery_podcast_delivery_files_bridge_params(podcast_deliveries)
      podcast_deliveries.map do |delivery|
        get_delivery_file_bridge_params(delivery.apple_episode_id,
          delivery.id,
          delivery.podcast_delivery_files_url)
      end
    end

    # Build up the bridge params for a single podcast delivery file
    # The api_url is agnostic as to which endpoint to hit, so we can use the same method
    def self.get_delivery_file_bridge_params(apple_episode_id, podcast_delivery_id, api_url)
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_delivery_id: podcast_delivery_id
        },
        api_url: api_url,
        api_parameters: {}
      }
    end

    def self.mark_uploaded_delivery_file_bridge_params(api, podcast_delivery_file)
      {
        request_metadata: {
          podcast_delivery_file_id: podcast_delivery_file.id,
          podcast_delivery_id: podcast_delivery_file.podcast_delivery.id
        },
        api_url: api.join_url("podcastDeliveryFiles/#{podcast_delivery_file.apple_id}").to_s,
        api_parameters: podcast_delivery_file.mark_uploaded_parameters
      }
    end

    def self.create_delivery_file_bridge_params(api, podcast_delivery)
      {
        request_metadata: {
          apple_episode_id: podcast_delivery.apple_episode_id,
          podcast_delivery_id: podcast_delivery.id
        },
        api_url: api.join_url("podcastDeliveryFiles").to_s,
        api_parameters: podcast_delivery_file_create_parameters(podcast_delivery)
      }
    end

    def self.podcast_delivery_file_create_parameters(podcast_delivery)
      podcast_container = podcast_delivery.podcast_container

      {data: {
        type: "podcastDeliveryFiles",
        attributes: {
          assetType: "ASSET",
          assetRole: "PodcastSourceAudio",
          fileSize: podcast_container.source_size,
          fileName: podcast_container.source_filename,
          uti: "public.json"
        },
        relationships: {
          podcastDelivery: {
            data: {
              type: "podcastDeliveries",
              id: podcast_delivery.external_id
            }
          }
        }
      }}
    end

    def self.upsert_podcast_delivery_file(podcast_delivery, row)
      external_id = row.dig("api_response", "val", "data", "id")
      podcast_delivery_id = row.dig("request_metadata", PODCAST_DELIVERY_ID_ATTR)

      (pdf, action) =
        if (delivery_file = where(episode_id: podcast_delivery.episode.id,
          external_id: external_id,
          podcast_delivery_id: podcast_delivery_id).first)

          delivery_file.update(api_response: row, updated_at: Time.now.utc)
          [delivery_file, :update]
        else
          delivery_file =
            Apple::PodcastDeliveryFile.create!(episode_id: podcast_delivery.episode.id,
              external_id: external_id,
              podcast_delivery_id: podcast_delivery_id,
              api_response: row)

          [delivery_file, :create]
        end

      Rails.logger.info("#{action} local podcast delivery file",
        {podcast_container_id: pdf.podcast_container.id,
         action: action,
         external_id: external_id,
         feeder_episode_id: pdf.episode.id,
         podcast_delivery_file_id: pdf.podcast_delivery.id})

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
      (apple_attributes["uploadOperations"] || []).map do |frag|
        Apple::UploadOperation.new(delivery_file: self, operation_fragment: frag)
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
