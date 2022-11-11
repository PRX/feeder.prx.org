# frozen_string_literal: true

module Apple
  class PodcastDelivery < ActiveRecord::Base
    include Apple::ApiResponse

    serialize :api_response, JSON

    has_many :podcast_delivery_files
    belongs_to :episode, class_name: "::Episode"
    belongs_to :podcast_container, class_name: "::Apple::PodcastContainer"

    delegate :apple_episode_id, to: :podcast_container

    enum status: {
      awaiting_upload: "AWAITING_UPLOAD",
      completed: "COMPLETED",
      failed: "FAILED"
    }

    def self.update_podcast_deliveries_state(api, episodes)
      results = get_podcast_deliveries_via_containers(api, episodes.map(&:podcast_container))

      join_on_apple_episode_id(episodes, results).map do |(episode, delivery_row)|
        upsert_podcast_delivery(episode, delivery_row)
      end
    end

    def self.create_podcast_deliveries(api, episodes_to_sync)
      episodes_needing_delivery = episodes_to_sync.reject do |episode|
        episode.podcast_container.podcast_deliveries.present?
      end

      deliveries_response =
        api.bridge_remote_and_retry!("createPodcastDeliveries",
                                     create_podcast_deliveries_bridge_params(api, episodes_needing_delivery))

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # resources created
      join_on_apple_episode_id(episodes_to_create, new_containers_response) do |episode, row|
        upsert_podcast_delivery(episode, row)
      end
    end

    def self.upsert_podcast_delivery(episode, row)
      external_id = row.dig("api_response", "val", "data", "id")
      delivery_status = row.dig("api_response", "val", "data", "attributes", "status")

      pd =
        if delivery = where(episode_id: episode.feeder_id,
                            external_id: external_id,
                            podcast_container: episode.podcast_container).first

          delivery.update(api_response: row, updated_at: Time.now.utc)
          Rails.logger.info("Updating local podcast delivery w/ Apple id #{external_id} for episode #{episode.feeder_id}")

          delivery
        else
          pd = Apple::PodcastDelivery.create!(episode_id: episode.feeder_id,
                                              external_id: external_id,
                                              status: delivery_status,
                                              podcast_container: episode.podcast_container,
                                              api_response: row)
          Rails.logger.info("Creating local podcast delivery w/ Apple id #{external_id} for episode #{episode.feeder_id}")
          pd
        end

      SyncLog.create!(feeder_id: pd.id, feeder_type: :podcast_deliveries, external_id: external_id)

      pd
    end

    def self.create_podcast_deliveries_bridge_params(api, episodes_to_sync)
      episodes_to_sync.map do |episode|
        {
          apple_episode_id: episode.apple_id,
          api_url: api.join_url("podcastDeliveries").to_s,
          api_parameters: podcast_delivery_create_parameters(episode)
        }
      end
    end

    def self.podcast_delivery_create_parameters(episode)
      {
        data: {
          type: "podcastDeliveries",
          relationships: {
            podcastContainer: {
              data: {
                type: "podcastContainers",
                id: episode.podcast_container.external_id
              }
            }
          }
        }
      }
    end

    def self.get_podcast_deliveries_via_containers(api, podcast_containers)
      # Fetch the podcast deliveries from the containers side of the api
      deliveries_response =
        api.bridge_remote_and_retry!("getPodcastDeliveries",
                                     get_podcast_containers_deliveries_bridge_params(podcast_containers))
      # Rather than mangling and persisting the enumerated view of the deliveries
      # Instead, re-fetch the podcast deliveries from the non-list podcast delivery endpoint
      formatted_bridge_params = join_on_apple_episode_id(podcast_containers, deliveries_response).map do |(pc, row)|
        get_urls_for_container_podcast_deliveries(api, row).map do |url|
          get_podcast_containers_deliveries_bridge_param(pc.apple_episode_id, pc.id, url)
        end
      end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!("getPodcastDeliveries",
                                   formatted_bridge_params)
    end

    def self.get_urls_for_container_podcast_deliveries(api, podcast_container_deliveries_json)
      podcast_container_deliveries_json["api_response"]["val"]["data"].map do |podcast_delivery_data|
        api.join_url("podcastDeliveries/#{podcast_delivery_data['id']}").to_s
      end
    end

    # Query from the podcast container side of the api
    def self.get_podcast_containers_deliveries_bridge_params(podcast_containers)
      podcast_containers.map do |container|
        get_podcast_containers_deliveries_bridge_param(container.apple_episode_id,
                                                       container.id,
                                                       container.podcast_deliveries_url)
      end
    end

    # Query from the podcast delivery side of the api
    def self.get_podcast_containers_deliveries_bridge_param(apple_episode_id, podcast_container_id, api_url)
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_container_id: podcast_container_id
        },
        api_url: api_url,
        api_parameters: {}
      }
    end

    def podcast_delivery_files_url
      apple_data.dig("relationships", "podcastDeliveryFiles", "links", "related")
    end

    def podcast_delivery_id
      id
    end
  end
end
