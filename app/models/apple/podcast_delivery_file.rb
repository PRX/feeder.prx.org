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

      resp =
        api.bridge_remote("headFileSizes", episodes_needing_delivery_files.map(&:head_file_size_bridge_params))

      # TODO: handle errors
      file_sizes_resp = api.unwrap_response(resp)

      episodes_by_id = episodes_needing_delivery_files.map { |ep| [ep.id, ep] }.to_h

      delivery_file_bridge_params =
        file_sizes_resp.map do |row|
          episode = episodes_by_id.fetch(row["episode_id"])
          file_size_bytes = row.dig("api_response", "val", "data", "content-length")
          file_size_bytes = Integer(file_size_bytes)
          create_delivery_file_bridge_params(api,
                                             episode,
                                             episode.enclosure_filename,
                                             file_size_bytes)
        end

      resp = api.bridge_remote("createDeliveryFiles", delivery_file_bridge_params)
      resp = api.unwrap_response(resp)

      resp.each do |row|
        ep = episodes_by_id.fetch(row["request_metadata"]["episode_id"])
        # TODO: parameterize multiple podcast deliveries per podcast container
        create_logs(ep, ep.podcast_container.podcast_delivery, row)
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

    def self.create_logs(ep, podcast_delivery, row)
      external_id = row.dig("api_response", "val", "data", "id")

      pc = Apple::PodcastDeliveryFile.create!(episode_id: ep.feeder_id,
                                              external_id: external_id,
                                              podcast_delivery_id: podcast_delivery.id,
                                              api_response: row)

      SyncLog.create!(feeder_id: pc.id, feeder_type: :podcast_containers, external_id: external_id)
    end

    def self.episode_zip; end

    def self.insert_sync_log(row)
      # we don't have the external ids loadded yet.
      # save an api call and redo the join like in
      delivery_file_apple_id = row.dig("api_response", "val", "data", "id")
      delivery_apple_id = row.dig("request_metadata", "podcast_delivery_id")

      podcast_delivery = Apple::PodcastDelivery.find_by_external_id!(delivery_apple_id)

      Apple::PodcastDeliveryFile.create!(podcast_delivery: podcast_delivery,
                                         episode_id: podcast_delivery.episode_id,
                                         external_id: delivery_file_apple_id,
                                         api_response: row)

      SyncLog.
        create(feeder_id: ep.feeder_id, feeder_type: "f", external_id: apple_id)
    end
  end
end
