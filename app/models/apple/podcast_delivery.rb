# frozen_string_literal: true

module Apple
  class PodcastDelivery < ActiveRecord::Base
    include Apple::ApiResponse

    serialize :api_response, JSON

    has_many :podcast_delivery_files
    belongs_to :episode, class_name: '::Episode'
    belongs_to :podcast_container, class_name: '::Apple::PodcastContainer'

    delegate :apple_episode_id, to: :podcast_container

    enum status: {
      awaiting_upload: 'AWAITING_UPLOAD',
      completed: 'COMPLETED',
      failed: 'FAILED'
    }

    def self.update_podcast_deliveries_state(api, episodes)
      podcast_containers = episodes.map do |ep|
        if ep.podcast_container.present?
          ep.podcast_container
        else
          Rails.logger.error("Missing podcast container for episode #{ep.feeder_id}")
          nil
        end
      end.compact

      results = get_podcast_deliveries_via_containers(api, podcast_containers)

      join_on('podcast_container_id', podcast_containers, results).map do |(podcast_container, delivery_row)|
        upsert_podcast_delivery(podcast_container, delivery_row)
      end
    end

    def self.create_podcast_deliveries(api, episodes)
      # TODO: Support multiple deliveries per episode
      podcast_containers = episodes.map(&:podcast_container)

      podcast_containers = podcast_containers.reject do |container|
        # Don't create deliveries for containers that already have deliveries.
        # An alternative workflow would be to swap out the existing delivery and
        # upload different audio.
        container.podcast_deliveries.present?
      end

      response =
        api.bridge_remote_and_retry!('createPodcastDeliveries',
                                     create_podcast_deliveries_bridge_params(api, podcast_containers))

      join_on('podcast_container_id', podcast_containers, response).map do |podcast_container, row|
        upsert_podcast_delivery(podcast_container, row)
      end
    end

    def self.get_podcast_deliveries_via_containers(api, podcast_containers)
      # Fetch the podcast deliveries from the containers side of the api
      deliveries_response =
        api.bridge_remote_and_retry!('getPodcastDeliveries',
                                     get_podcast_containers_deliveries_bridge_params(podcast_containers))
      # Rather than mangling and persisting the enumerated view of the deliveries from the containers endpoint,
      # Instead, re-fetch the podcast deliveries from the non-list podcast delivery endpoint
      formatted_bridge_params = join_on('podcast_container_id',
                                        podcast_containers,
                                        deliveries_response).map do |(pc, row)|
        get_urls_for_container_podcast_deliveries(api, row).map do |url|
          get_podcast_containers_deliveries_bridge_param(pc.apple_episode_id, pc.id, url)
        end
      end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!('getPodcastDeliveries',
                                   formatted_bridge_params)
    end

    def self.upsert_podcast_delivery(podcast_container, row)
      external_id = row.dig('api_response', 'val', 'data', 'id')
      delivery_status = row.dig('api_response', 'val', 'data', 'attributes', 'status')

      pd =
        if delivery = where(episode_id: podcast_container.episode.id,
                            external_id: external_id,
                            podcast_container: podcast_container).first

          Rails.logger.info("Update local podcast delivery w/ Apple id #{external_id} for episode #{podcast_container.episode.id}")
          delivery.update(api_response: row, updated_at: Time.now.utc)

          delivery
        else
          Rails.logger.info("Creating local podcast delivery w/ Apple id #{external_id} for episode #{podcast_container.episode.id}")
          Apple::PodcastDelivery.create!(episode_id: podcast_container.episode.id,
                                         external_id: external_id,
                                         status: delivery_status,
                                         podcast_container: podcast_container,
                                         api_response: row)
        end

      # Flush the cache on the podcast container
      podcast_container.podcast_deliveries.reset

      SyncLog.create!(feeder_id: pd.id, feeder_type: :podcast_deliveries, external_id: external_id)

      pd
    end

    def self.create_podcast_deliveries_bridge_params(api, podcast_containers)
      podcast_containers.map do |container|
        {
          request_metadata: { podcast_container_id: container.id },
          api_url: api.join_url('podcastDeliveries').to_s,
          api_parameters: podcast_delivery_create_parameters(container)
        }
      end
    end

    def self.podcast_delivery_create_parameters(podcast_container)
      {
        data: {
          type: 'podcastDeliveries',
          relationships: {
            podcastContainer: {
              data: {
                type: 'podcastContainers',
                id: podcast_container.external_id
              }
            }
          }
        }
      }
    end

    def self.get_urls_for_container_podcast_deliveries(api, podcast_container_deliveries_json)
      podcast_container_deliveries_json['api_response']['val']['data'].map do |podcast_delivery_data|
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
      apple_data.dig('relationships', 'podcastDeliveryFiles', 'links', 'related')
    end

    def podcast_delivery_id
      id
    end
  end
end
