# frozen_string_literal: true

module Apple
  class Episode
    attr_accessor :show, :feeder_episode, :api

    def self.get_episodes(api, episodes)
      return if episodes.empty?

      api.bridge_remote_and_retry!("getEpisodes", episodes.map(&:get_episode_bridge_params))
    end

    def self.create_episodes(api, episodes)
      return if episodes.empty?

      episode_bridge_results = api.bridge_remote_and_retry!("createEpisodes",
        episodes.map(&:create_episode_bridge_params))

      insert_sync_logs(episodes, episode_bridge_results)
    end

    def self.update_audio_container_reference(api, episodes)
      return [] if episodes.empty?

      episode_bridge_results = api.bridge_remote_and_retry!("updateEpisodes",
        episodes.map(&:update_episode_audio_container_bridge_params))
      insert_sync_logs(episodes, episode_bridge_results)
    end

    def self.publish(api, episodes)
      return [] if episodes.empty?

      api.bridge_remote_and_retry!("publishEpisodes",
        episodes.map(&:publish_episode_bridge_params))
    end

    def self.insert_sync_logs(episodes, results)
      episodes_by_item_guid = episodes.map { |ep| [ep.item_guid, ep] }.to_h

      results.map do |res|
        apple_id = res.dig("api_response", "val", "data", "id")
        guid = res.dig("api_response", "val", "data", "attributes", "guid")
        ep = episodes_by_item_guid.fetch(guid)

        SyncLog
          .create(feeder_id: ep.feeder_episode.id, feeder_type: :episodes, external_id: apple_id)
      end
    end

    def self.add_no_imp_param(url)
      # use the URI class to add a 'noImp' query param
      url = URI.parse(url)
      decoded_query = URI.decode_www_form(url.query.to_s) << ["noImp", "1"]
      url.query = URI.encode_www_form(decoded_query)
      url.to_s
    end

    def initialize(show:, feeder_episode:, api: nil)
      @show = show
      @feeder_episode = feeder_episode
      @api = api || Apple::Api.from_env
    end

    def item_guid
      feeder_episode.item_guid
    end

    def feeder_id
      feeder_episode.id
    end

    def enclosure_url
      self.class.add_no_imp_param(feeder_episode.enclosure_url)
    end

    def enclosure_filename
      feeder_episode.enclosure_filename
    end

    def apple_json
      return nil unless show.apple_id.present?

      eps = show.get_episodes_json

      eps.detect { |ep| ep["attributes"]["guid"] == feeder_episode.item_guid }
    end

    def completed_sync_log
      SyncLog
        .episodes
        .complete
        .latest
        .where(feeder_id: feeder_episode.id, feeder_type: :episodes)
        .first
    end

    def get_episode_bridge_params
      {
        api_url: api.join_url("episodes/#{apple_id}").to_s,
        api_parameters: {}
      }
    end

    def create_episode_bridge_params
      {
        api_url: api.join_url("episodes").to_s,
        api_parameters: episode_create_parameters
      }
    end

    def episode_create_parameters
      explicit = feeder_episode.explicit.present? && feeder_episode.explicit == "true"

      {
        data:
        {
          type: "episodes",
          attributes: {
            guid: feeder_episode.item_guid,
            title: feeder_episode.title,
            originalReleaseDate: feeder_episode.published_at.utc.iso8601,
            description: feeder_episode.description || feeder_episode.subtitle,
            websiteUrl: feeder_episode.url,
            explicit: explicit,
            episodeNumber: feeder_episode.episode_number,
            seasonNumber: feeder_episode.season_number,
            episodeType: feeder_episode.itunes_type.upcase,
            appleHostedAudioIsSubscriberOnly: true
          },
          relationships: {
            show: {data: {type: "shows", id: show.apple_id}}
          }
        }
      }
    end

    def update_episode_audio_container_bridge_params
      {
        api_url: api.join_url("episodes/#{apple_id}").to_s,
        api_parameters: update_episode_audio_container_parameters
      }
    end

    def update_episode_audio_container_parameters
      {
        data:
        {
          type: "episodes",
          id: apple_id,
          attributes: {
            appleHostedAudioAssetContainerId: podcast_container.apple_id,
            appleHostedAudioIsSubscriberOnly: true
          }
        }
      }
    end

    def publish_episode_bridge_params
      {
        api_url: api.join_url("episodePublishingRequests").to_s,
        api_parameters: publish_episode_parameters
      }
    end

    def publish_episode_parameters
      {
        data: {
          type: "episodePublishingRequests",
          attributes: {
            action: "PUBLISH"
          },
          relationships: {
            episode: {
              data: {
                id: apple_id,
                type: "episodes"
              }
            }
          }
        }
      }
    end

    def create_episode!
      self.class.create_apple_episodes([self])

      api.unwrap_response(resp)
    end

    def update_episode!
      resp = api.patch("episodes/#{apple_id}", update_episode_data)

      api.unwrap_response(resp)
    end

    def apple?
      feeder_episode.apple?
    end

    def apple_new?
      !apple_persisted?
    end

    def apple_persisted?
      apple_json.present?
    end

    def drafting?
      apple_json&.dig("attributes", "publishingState") == "DRAFTING"
    end

    def apple_upload_complete?
      pdfs = feeder_episode.apple_podcast_delivery_files

      pdfs.all?(&:present?) && pdfs.to_a.flatten.all?(&:apple_complete?)
    end

    def audio_asset_vendor_id
      apple_json&.dig("attributes", "appleHostedAudioAssetVendorId")
    end

    def apple_id
      apple_json&.dig("id")
    end

    def apple_episode_id
      apple_id
    end

    def podcast_container
      feeder_episode.podcast_container
    end

    def podcast_deliveries
      feeder_episode.apple_podcast_deliveries
    end

    def podcast_delivery_files
      feeder_episode.apple_podcast_delivery_files
    end
  end
end
