# frozen_string_literal: true

module Apple
  class PodcastContainer < ActiveRecord::Base
    serialize :api_response, JSON

    has_one :podcast_delivery
    belongs_to :episode, class_name: "::Episode"

    def podcast_deliveries_url
      api_response.dig("data", "relationships", "podcastDeliveries", "links", "self")
    end

    def self.zip_result_with_episode(result, eps)
      episodes_by_id = eps.map { |ep| [ep.apple_id, ep] }.to_h

      result.map do |row|
        ep = episodes_by_id.fetch(row["request_metadata"]["apple_episode_id"])
        [ep, row]
      end
    end

    def self.update_podcast_container_file_metadata(api, episodes)
      containers = Apple::PodcastContainer.where(episode_id: episodes.map(&:feeder_id))
      containers_by_id = containers.map { |c| [c.id, c] }.to_h

      api.bridge_remote_and_retry!("headFileSizes", containers.map(&:head_file_size_bridge_params)).
        map do |row|
        content_length = row.dig("api_response", "val", "data", "content-length")

        podcast_container_id = row["request_metadata"]["podcast_container_id"]

        container = containers_by_id.fetch(podcast_container_id)
        container.source_size = content_length

        container.save!
        container
      end
    end

    def self.update_podcast_container_state(api, episodes)
      results = get_podcast_containers(api, episodes)

      zip_result_with_episode(results, episodes).each do |(ep, row)|
        podcast_containers_json = row.dig("api_response", "val", "data")
        upsert_podcast_container(ep, row)
      end
    end

    def self.create_podcast_containers(api, episodes)
      # TODO: guard gatekeep the initial sync to preserve podcast connect audio.
      # TODO: guard at the feed level -- accept list feeds for sync
      # TODO: guard for existing media via podcast connect.
      #
      episodes_to_create = episodes.reject { |ep| ep.podcast_container.present? }

      new_containers_response =
        api.bridge_remote_and_retry!("createPodcastContainers",
                                     create_podcast_containers_bridge_params(api, episodes_to_create))

      zip_result_with_episode(new_containers_response, episodes_to_create) do |ep, row|
        upsert_podcast_container(ep, row)
      end
    end

    def self.upsert_podcast_container(episode, row)
      podcast_containers_json = row.dig("api_response", "val", "data")

      # TODO: support > 1 podcast container
      (row, external_id) =
        if podcast_containers_json.is_a?(Array)
          raise "Unsupported number of podcast containers for episode: #{ep.feeder_id}" if podcast_containers_json.length > 1

          container = podcast_containers_json.first.dup

          single_container_row = row.dup
          single_container_row["api_response"]["val"]["data"] = container
          [single_container_row, container["id"]]
        else
          [row, row.dig("api_response", "val", "data", "id")]
        end

      pc =
        if pc = where(episode_id: episode.feeder_id,
                      apple_episode_id: episode.apple_id,
                      vendor_id: episode.audio_asset_vendor_id,
                      external_id: external_id).first
          pc.update!(api_response: row)
          pc
        else
          create!(episode_id: episode.feeder_id,
                  external_id: external_id,
                  vendor_id: episode.audio_asset_vendor_id,
                  apple_episode_id: episode.apple_id,
                  source_url: episode.enclosure_url,
                  source_filename: episode.enclosure_filename,
                  api_response: row)
        end

      SyncLog.create!(feeder_id: pc.id, feeder_type: :podcast_containers, external_id: external_id)

      pc
    end

    def self.get_podcast_containers(api, episodes)
      api.bridge_remote_and_retry!("getPodcastContainers", get_podcast_containers_bridge_params(api, episodes))
    end

    def self.get_podcast_containers_bridge_params(api, episodes)
      episodes.map do |ep|
        {
          request_metadata: { apple_episode_id: ep.apple_id },
          api_url: podcast_container_url(api, ep),
          api_parameters: {}
        }
      end
    end

    def self.create_podcast_containers_bridge_params(api, episodes)
      episodes.
        map do |ep|
        {
          request_metadata: { apple_episode_id: ep.id },
          api_url: api.join_url("podcastContainers").to_s,
          api_parameters: podcast_container_create_parameters(ep)
        }
      end
    end

    def self.podcast_container_create_parameters(ep)
      {
        data: {
          type: "podcastContainers",
          attributes: {
            vendorId: ep.audio_asset_vendor_id
          }
        }
      }
    end

    def self.podcast_containers_parameters(ep)
      {
        data: {
          type: "podcastContainers",
          attributes: {
            vendorId: ep.audio_asset_vendor_id,
            id: ep.podcast_container.external_id
          }
        }
      }
    end

    def self.podcast_container_url(api, episode)
      return nil unless episode.audio_asset_vendor_id.present?

      api.join_url("podcastContainers?filter[vendorId]=" + episode.audio_asset_vendor_id).to_s
    end

    def head_file_size_bridge_params
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_container_id: id
        },
        api_url: source_url,
        api_parameters: {}
      }
    end
  end
end
