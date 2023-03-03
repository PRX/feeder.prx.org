# frozen_string_literal: true

module Apple
  class Episode
    include Apple::ApiWaiting
    include Apple::ApiResponse
    attr_accessor :show, :feeder_episode, :api, :api_response

    AUDIO_ASSET_FAILURE = "FAILURE"
    AUDIO_ASSET_SUCCESS = "SUCCESS"

    def self.wait_for_asset_state(api, eps)
      wait_for(eps) do |remaining_eps|
        Rails.logger.info("Probing for episode audio asset state")
        unwrapped = get_episodes(api, remaining_eps)

        remote_ep_by_id = unwrapped.map { |row| [row["request_metadata"]["guid"], row] }.to_h
        remaining_eps.each { |ep| ep.api_response = remote_ep_by_id[ep.guid] }

        rem =
          remaining_eps.filter do |ep|
            if ep.waiting_for_asset_state?
              Rails.logger.info("Waiting for audio asset state", {episode_id: ep.feeder_id,
                                                                      delivery_file_count: ep.podcast_delivery_files.count,
                                                                      delivery_files_processed_errors: ep.podcast_delivery_files.all?(&:processed_errors?),
                                                                      delivery_files_processed: ep.podcast_delivery_files.all?(&:processed?),
                                                                      delivery_files_delivered: ep.podcast_delivery_files.all?(&:delivered?),
                                                                      asset_state: ep.audio_asset_state,
                                                                      has_podcast_audio: ep&.podcast_container&.has_podcast_audio?})
              true
            end
          end

        if rem.length > 0
          Rails.logger.info("Waiting for asset state processing", {audio_asset_states: rem.map(&:audio_asset_state).uniq})
        end

        rem
      end
    end

    def self.get_episodes(api, episodes)
      return if episodes.empty?

      api.bridge_remote_and_retry!("getEpisodes", episodes.map(&:get_episode_bridge_params))
    end

    def self.get_episodes_via_show(api, show_id)
      bridge_params = Apple::Show.apple_episode_json(api, show_id).map do |ep_json|
        id = ep_json["id"]
        guid = ep_json["attributes"]["guid"]
        Episode.get_episode_bridge_params(api, id, guid)
      end

      api.bridge_remote_and_retry!("getEpisodes", bridge_params)
    end

    def self.create_episodes(api, episodes)
      return if episodes.empty?

      episode_bridge_results = api.bridge_remote_and_retry!("createEpisodes",
        episodes.map(&:create_episode_bridge_params))

      insert_sync_logs(episodes, episode_bridge_results)
    end

    def self.update_audio_container_reference(api, episodes)
      return [] if episodes.empty?

      # Make sure that we only update episodes that have a podcast container
      # And that the episode needs to be updated
      episodes = episodes.filter { |ep| ep.podcast_container.present? && ep.audio_hosted_audio_asset_container_id.blank? }

      (episode_bridge_results, errs) =
        api.bridge_remote_and_retry(
          "updateEpisodes",
          episodes.map(&:update_episode_audio_container_bridge_params)
        )

      insert_sync_logs(episodes, episode_bridge_results)

      api.raise_bridge_api_error(errs) if errs.present?

      episode_bridge_results
    end

    def self.publish(api, episodes)
      return [] if episodes.empty?

      api.bridge_remote_and_retry!("publishEpisodes",
        episodes.map(&:publish_episode_bridge_params))
    end

    def self.insert_sync_logs(episodes, results)
      episodes_by_guid = episodes.map { |ep| [ep.guid, ep] }.to_h

      results.map do |res|
        apple_id = res.dig("api_response", "val", "data", "id")
        guid = res.dig("api_response", "val", "data", "attributes", "guid")
        ep = episodes_by_guid.fetch(guid)

        SyncLog
          .create(feeder_id: ep.feeder_episode.id, feeder_type: :episodes, external_id: apple_id)
      end
    end

    def initialize(show:, feeder_episode:, api:, api_response: nil)
      @show = show
      @feeder_episode = feeder_episode
      @api_response = api_response
      @api = api || Apple::Api.from_env
    end

    def guid
      feeder_episode.item_guid
    end

    def feeder_id
      feeder_episode.id
    end

    def private_feed
      show.private_feed
    end

    def podcast
      show.podcast
    end

    def enclosure_url
      url = EnclosureUrlBuilder.new.base_enclosure_url(podcast, feeder_episode, private_feed)
      url = EnclosureUrlBuilder.mark_no_imp(url)
      EnclosureUrlBuilder.mark_authorized(url, show.private_feed)
    end

    def enclosure_filename
      feeder_episode.enclosure_filename
    end

    def completed_sync_log
      SyncLog
        .episodes
        .complete
        .latest
        .where(feeder_id: feeder_episode.id, feeder_type: :episodes)
        .first
    end

    def self.get_episode_bridge_params(api, apple_id, guid)
      {
        request_metadata: {
          apple_episode_id: apple_id,
          guid: guid
        },
        api_url: api.join_url("episodes/#{apple_id}").to_s,
        api_parameters: {}
      }
    end

    def get_episode_bridge_params
      self.class.get_episode_bridge_params(api, apple_id, guid)
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
            guid: guid,
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

    def apple_json
      return nil unless api_response.present?

      apple_data
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
      apple_attributes["appleHostedAudioAssetVendorId"]
    end

    def audio_hosted_audio_asset_container_id
      apple_attributes["appleHostedAudioAssetContainerId"]
    end

    def audio_asset_state
      apple_attributes["appleHostedAudioAssetState"]
    end

    def audio_asset_state_finished?
      audio_asset_state_error? || audio_asset_state_success?
    end

    def audio_asset_state_error?
      audio_asset_state == AUDIO_ASSET_FAILURE
    end

    def audio_asset_state_success?
      audio_asset_state == AUDIO_ASSET_SUCCESS
    end

    def waiting_for_asset_state?
      (podcast_delivery_files.length > 0 &&
        podcast_delivery_files.all?(&:delivered?) &&
        podcast_delivery_files.all?(&:processed?) &&
        !podcast_delivery_files.all?(&:processed_errors?) &&
        !audio_asset_state_finished?)
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
