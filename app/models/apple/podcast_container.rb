# frozen_string_literal: true

module Apple
  class PodcastContainer < ActiveRecord::Base
    serialize :api_response, JSON

    has_one :podcast_delivery
    belongs_to :episode, class_name: "::Episode"

    def podcast_deliveries_url
      api_response.dig("data", "relationships", "podcastDeliveries", "links", "self")
    end

    def self.create_podcast_containers(api, episodes_to_sync, show)
      episodes_to_create = episodes_to_sync.reject { |ep| ep.podcast_container.present? }

      api_resp =
        api.bridge_remote("createPodcastContainers",
                          create_podcast_containers_bridge_params(api, episodes_to_create))

      # TODO: error handling
      new_containers_response = api.unwrap_response(api_resp)

      show.reload

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # podcast containers created (`create_metadata`)

      episodes_by_id = episodes_to_create.map { |ep| [ep.id, ep] }.to_h

      new_containers_response.map do |row|
        ep = episodes_by_id.fetch(row["episode_id"])

        create_logs(ep, row)
      end
    end

    def self.create_logs(ep, row)
      external_id = row.dig("api_response", "val", "data", "id")

      pc =
        if pc = where(episode_id: ep.feeder_id, external_id: external_id).first
          pd.update!(api_response: row)
          pc
        else
          create!(episode_id: ep.feeder_id,
                  external_id: external_id,
                  api_response: row)
        end

      SyncLog.create!(feeder_id: pc.id, feeder_type: "c", external_id: external_id)
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
  end
end
