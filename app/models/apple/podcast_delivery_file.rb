# frozen_string_literal: true

module Apple
  class PodcastDeliveryFile < ActiveRecord::Base
    serialize :api_response, JSON

    belongs_to :podcast_delivery
    belongs_to :episode, class_name: "::Episode"

    def self.create_podcast_delivery_files(api, episodes)
      return [] if episodes.empty?
      episodes_needing_delivery_files =
        episodes.reject { |ep| ep.podcast_container&.podcast_delivery&.podcast_delivery_file.present? }

      resp = api.bridge_remote("createDeliveryFiles", create_delivery_file_bridge_params)
      resp = api.unwrap_response(resp).each do |row|
        ep = episodes_by_id.fetch(row["request_metadata"]["episode_id"])
        create_podcast_delivery_file(ep, ep.podcast_container.podcast_delivery, row)
      end

      # episode_bridge_results
    end

    def self.create_delivery_file_bridge_params(api, episode, filename, num_bytes)
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

    def self.podcast_delivery_file_create_parameters(podcast_delivery, filename, num_bytes)
      { "data": {
        "type": "podcastDeliveryFiles",
        "attributes": {
          "assetType": "ASSET",
          "assetRole": "PodcastSourceAudio", # TODO: handle images also
          "fileSize": num_bytes,
          "fileName": filename,
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

    def upload_operations(episode)
      apple_attributes["uploadOperations"].map do |_operation_fragment|
        Apple::UploadOperation.new(episode)
      end
    end

    def unwrap_response
      raise "incomplete api response" unless api_response.dig("api_response", "ok")

      api_response["api_response"]["val"]
    end

    def data
      unwrap_response["data"]
    end

    def apple_attributes
      data["attributes"]
    end
  end
end
