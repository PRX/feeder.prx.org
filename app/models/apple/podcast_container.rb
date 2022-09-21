# frozen_string_literal: true

module Apple
  class PodcastContainer < ActiveRecord::Base
    serialize :api_response, JSON

    has_one :podcast_delivery
    belongs_to :episode, class_name: "::Episode"

    def podcast_deliveries_url
      api_response.dig("data", "relationships", "podcastDeliveries", "links", "self")
    end

    def self.update_podcast_container_file_metadata(api, episodes_to_sync)
      containers = Apple::PodcastContainer.where(episode_id: episodes_to_sync.map(&:feeder_id))
      containers_by_id = containers.map { |c| [c.id, c] }.to_h

      resp =
        api.bridge_remote("headFileSizes", containers.map(&:head_file_size_bridge_params))

      api.unwrap_response(resp).map do |row|
        content_length = row.dig("api_response", "val", "data", "content-length")

        podcast_container_id = row["request_metadata"]["podcast_container_id"]

        container = containers_by_id.fetch(podcast_container_id)
        container.source_size = content_length

        container.save!
        container
      end
    end

    def self.create_podcast_containers(api, episodes_to_sync, show)
      # TODO: guard gatekeep the initial sync to preserve podcast connect audio.
      # TODO: guard at the feed level -- accept list feeds for sync
      # TODO: guard for existing media via podcast connect.
      #
      episodes_to_create = episodes_to_sync.reject { |ep| ep.podcast_container.present? }

      api_resp =
        api.bridge_remote("createPodcastContainers",
                          create_podcast_containers_bridge_params(api, episodes_to_create))

      # TODO: error handling
      new_containers_response = api.unwrap_response(api_resp)

      # fetch and in
      show.reload

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # resources created.

      episodes_by_id = episodes_to_create.map { |ep| [ep.id, ep] }.to_h

      new_containers_response.map do |row|
        ep = episodes_by_id.fetch(row["episode_id"])

        create_podcast_container(ep, row)
      end
    end

    def self.create_podcast_container(ep, row)
      external_id = row.dig("api_response", "val", "data", "id")

      pc =
        if pc = where(episode_id: ep.feeder_id,
                      apple_episode_id: ep.apple_id,
                      vendor_id: ep.audio_asset_vendor_id,
                      external_id: external_id).first
          pd.update!(api_response: row)
          pc
        else
          create!(episode_id: ep.feeder_id,
                  external_id: external_id,
                  vendor_id: ep.audio_asset_vendor_id,
                  apple_episode_id: ep.apple_id,
                  source_url: ep.enclosure_url,
                  source_filename: ep.enclosure_filename,
                  api_response: row)
        end

      SyncLog.create!(feeder_id: pc.id, feeder_type: :podcast_containers, external_id: external_id)

      pc
    end

    def self.get_podcast_containers(api, episodes_to_sync)
      resp =
        api.bridge_remote("getPodcastContainers", get_podcast_containers_bridge_params(api, episodes_to_sync))

      api.unwrap_response(resp)
    end

    def self.get_podcast_containers_bridge_params(api, episodes_to_sync)
      episodes_to_sync.map do |ep|
        {
          apple_episode_id: ep.id,
          api_url: podcast_container_url(api, ep),
          api_config: {}
        }
      end
    end

    def self.create_podcast_containers_bridge_params(api, episodes_to_sync)
      episodes_to_sync.
        map do |ep|
        {
          episode_id: ep.id,
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
      api.join_url("podcastContainers?filter[vendorId]=" + episode.audio_asset_vendor_id).to_s
    end

    def head_file_size_bridge_params
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_container_id: id,
        },
        api_url: source_url,
        api_parameters: {},
      }
    end
  end
end
