# frozen_string_literal: true

module Apple
  class PodcastDelivery < ActiveRecord::Base
    serialize :api_response, JSON

    has_one :podcast_delivery_file
    belongs_to :episode, class_name: "::Episode"
    belongs_to :podcast_container, class_name: "::Apple::PodcastContainer"

    enum status: {
      awaiting_upload: "AWAITING_UPLOAD",
      completed: "COMPLETED",
      failed: "FAILED"
    }

    def self.create_podcast_deliveries(api, episodes_to_sync)
      episodes_needing_delivery = episodes_to_sync.reject { |ep| ep.podcast_container.podcast_delivery.present? }

      new_deliveries_response =
        api.bridge_remote_and_retry!("createPodcastDeliveries",
                                     create_podcast_deliveries_bridge_params(api, episodes_needing_delivery))

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # resources created

      episodes_by_id = episodes_needing_delivery.map { |ep| [ep.id, ep] }.to_h

      new_deliveries_response.map do |row|
        ep = episodes_by_id.fetch(row["episode_id"])
        create_logs(ep, row)
      end
    end

    def self.create_logs(ep, row)
      external_id = row.dig("api_response", "val", "data", "id")
      delivery_status = row.dig("api_response", "val", "data", "attributes", "status")

      pc = Apple::PodcastDelivery.create!(episode_id: ep.feeder_id,
                                          external_id: external_id,
                                          status: delivery_status,
                                          podcast_container: ep.podcast_container,
                                          api_response: row)

      SyncLog.create!(feeder_id: pc.id, feeder_type: :podcast_deliveries, external_id: external_id)
    end

    def self.create_podcast_deliveries_bridge_params(api, episodes_to_sync)
      episodes_to_sync.map do |ep|
        {
          episode_id: ep.id,
          api_url: api.join_url("podcastDeliveries").to_s,
          api_parameters: podcast_delivery_create_parameters(ep)
        }
      end
    end

    def self.podcast_delivery_create_parameters(ep)
      {
        data: {
          type: "podcastDeliveries",
          relationships: {
            podcastContainer: {
              data: {
                type: "podcastContainers",
                id: ep.podcast_container.external_id
              }
            }
          }
        }
      }
    end
  end
end
