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
      episodes_needing_delivery = episodes_to_sync.reject do |episode|
        episode.podcast_container.podcast_delivery.present?
      end

      new_deliveries_response =
        api.bridge_remote_and_retry!("createPodcastDeliveries",
                                     create_podcast_deliveries_bridge_params(api, episodes_needing_delivery))

      # Make sure we have local copies of the remote metadata At this point and
      # errors should be resolved and we should have then intended set of
      # resources created

      episodes_by_id = episodes_needing_delivery.map { |episode| [episode.id, episode] }.to_h

      new_deliveries_response.map do |row|
        episode = episodes_by_id.fetch(row["episode_id"])
        create_logs(episode, row)
      end
    end

    def self.upsert_podcast_delivery(episode, row)
      external_id = row.dig("api_response", "val", "data", "id")
      delivery_status = row.dig("api_response", "val", "data", "attributes", "status")

      pd =
        if delivery = where(episode_id: episode.feeder_id,
                            external_id: external_id,
                            podcast_container: episode.podcast_container).first

          delivery.api_response = row
          delivery.save
          Logger.info("Updating podcast delivery w/ Apple id #{external_id} for episode #{episode.feeder_id}")

          delivery
        else
          Apple::PodcastDelivery.create!(episode_id: episode.feeder_id,
                                         external_id: external_id,
                                         status: delivery_status,
                                         podcast_container: episode.podcast_container,
                                         api_response: row)
          Logger.info("Creating podcast delivery w/ Apple id #{external_id} for episode #{episode.feeder_id}")
        end

      SyncLog.create!(feeder_id: pd.id, feeder_type: :podcast_deliveries, external_id: external_id)

      pd
    end

    def self.create_podcast_deliveries_bridge_params(api, episodes_to_sync)
      episodes_to_sync.map do |episode|
        {
          episode_id: episode.id,
          api_url: api.join_url("podcastDeliveries").to_s,
          api_parameters: podcast_delivery_create_parameters(ep)
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
  end
end
