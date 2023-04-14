# frozen_string_literal: true

module Apple
  class PodcastDelivery < ActiveRecord::Base
    include Apple::ApiResponse

    acts_as_paranoid

    serialize :api_response, JSON

    has_many :podcast_delivery_files, dependent: :destroy
    belongs_to :episode, class_name: "::Episode"
    belongs_to :podcast_container, class_name: "::Apple::PodcastContainer"

    delegate :apple_episode_id, to: :podcast_container

    enum status: {
      awaiting_upload: "AWAITING_UPLOAD",
      completed: "COMPLETED",
      failed: "FAILED"
    }

    def self.missing_container_for_episode(ep)
      Rails.logger.warn("Missing podcast container for episode",
        {feeder_episode_id: ep.feeder_id})
    end

    def self.poll_podcast_deliveries_state(api, episodes)
      podcast_containers = episodes.map do |ep|
        if ep.podcast_container.present?
          ep.podcast_container
        else
          missing_container_for_episode(ep)
          next
        end
      end.compact

      results = get_podcast_deliveries_via_containers(api, podcast_containers)

      join_many_on("podcast_container_id", podcast_containers, results, left_join: true).map do |(podcast_container, delivery_rows)|
        next if delivery_rows.nil?

        delivery_rows.each do |delivery_row|
          upsert_podcast_delivery(podcast_container, delivery_row)
        end
      end
    end

    def self.select_containers_for_delivery(podcast_containers)
      podcast_containers
        .select(&:needs_delivery?)
        .compact
    end

    def self.create_podcast_deliveries(api, episodes)
      podcast_containers = episodes.filter_map do |ep|
        if ep.podcast_container.nil?
          missing_container_for_episode(ep)
          next
        end

        ep.podcast_container
      end

      # Don't create deliveries for containers that already have deliveries.
      # An alternative workflow would be to swap out the existing delivery and
      # upload different audio.
      #
      # The overall publishing workflow dependes on the assumption that there is
      # a delivery present. If we don't create a delivery here, we short-circuit
      # subsequent steps (no uploads, no audio linking).
      podcast_containers = select_containers_for_delivery(podcast_containers)

      (response, errs) =
        api.bridge_remote_and_retry("createPodcastDeliveries",
          create_podcast_deliveries_bridge_params(api, podcast_containers), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE)

      join_on("podcast_container_id", podcast_containers, response).map do |podcast_container, row|
        upsert_podcast_delivery(podcast_container, row)
      end

      api.raise_bridge_api_error(errs) if errs.present?

      response
    end

    def self.get_podcast_deliveries_via_containers(api, podcast_containers)
      # Fetch the podcast deliveries from the containers side of the api
      bridge_params = podcast_containers.map do |pc|
        get_podcast_containers_deliveries_bridge_param(pc)
      end

      deliveries_response =
        api.bridge_remote_and_retry!("getPodcastDeliveries", bridge_params, batch_size: 1)

      # Rather than mangling and persisting the enumerated view of the deliveries from the containers endpoint,
      # Instead, re-fetch the podcast deliveries from the non-list podcast delivery endpoint
      formatted_bridge_params = join_many_on("podcast_container_id", podcast_containers, deliveries_response).map do |(pc, rows)|
        rows.map do |row|
          get_urls_for_container_podcast_deliveries(api, row).map do |url|
            get_podcast_deliveries_bridge_param(pc.apple_episode_id, pc.id, url)
          end
        end
      end

      formatted_bridge_params = formatted_bridge_params.flatten

      api.bridge_remote_and_retry!("getPodcastDeliveries",
        formatted_bridge_params, batch_size: 1)
    end

    def self.upsert_podcast_delivery(podcast_container, row)
      external_id = row.dig("api_response", "val", "data", "id")
      delivery_status = row.dig("api_response", "val", "data", "attributes", "status")
      raise "Missing external_id" if external_id.blank?

      (pd, action) =
        if (delivery = with_deleted.where(episode_id: podcast_container.episode.id,
          external_id: external_id,
          podcast_container: podcast_container).first)

          delivery.update(api_response: row, updated_at: Time.now.utc)

          [delivery, :updated]
        else
          delivery =
            Apple::PodcastDelivery.create!(episode_id: podcast_container.episode.id,
              external_id: external_id,
              status: delivery_status,
              podcast_container: podcast_container,
              api_response: row)
          [delivery, :created]
        end

      Rails.logger.info("#{action} local podcast delivery",
        {podcast_container_id: podcast_container.id,
         action: action,
         external_id: external_id,
         feeder_episode_id: podcast_container.episode.id,
         podcast_delivery_id: delivery.id})

      # Flush the cache on the podcast container
      podcast_container.podcast_deliveries.reset

      SyncLog.create!(feeder_id: pd.id, feeder_type: :podcast_deliveries, external_id: external_id)

      pd
    end

    def self.create_podcast_deliveries_bridge_params(api, podcast_containers)
      podcast_containers.map do |container|
        {
          request_metadata: {podcast_container_id: container.id},
          api_url: api.join_url("podcastDeliveries").to_s,
          api_parameters: podcast_delivery_create_parameters(container)
        }
      end
    end

    def self.podcast_delivery_create_parameters(podcast_container)
      {
        data: {
          type: "podcastDeliveries",
          relationships: {
            podcastContainer: {
              data: {
                type: "podcastContainers",
                id: podcast_container.external_id
              }
            }
          }
        }
      }
    end

    def self.get_urls_for_container_podcast_deliveries(api, podcast_container_deliveries_json)
      podcast_container_deliveries_json["api_response"]["val"]["data"].map do |podcast_delivery_data|
        api.join_url("podcastDeliveries/#{podcast_delivery_data["id"]}").to_s
      end
    end

    # Query from the podcast container side of the api
    def self.get_podcast_containers_deliveries_bridge_param(container)
      {
        request_metadata: {
          apple_episode_id: container.apple_episode_id,
          podcast_container_id: container.id
        },
        api_url: container.podcast_deliveries_url,
        api_parameters: {}
      }
    end

    # Query from the podcast delivery side of the api
    def self.get_podcast_deliveries_bridge_param(apple_episode_id, podcast_container_id, api_url)
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
