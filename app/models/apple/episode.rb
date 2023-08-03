# frozen_string_literal: true

module Apple
  class Episode
    include Apple::ApiWaiting
    include Apple::ApiResponse
    attr_accessor :show,
      :feeder_episode,
      :api,
      :apple_episode_update_attributes

    AUDIO_ASSET_FAILURE = "FAILURE"
    AUDIO_ASSET_SUCCESS = "SUCCESS"

    EPISODE_ASSET_WAIT_TIMEOUT = 8.minutes.freeze
    EPISODE_ASSET_WAIT_INTERVAL = 10.seconds.freeze

    # In the case where the episodes state is not yet ready to publish, but the
    # underlying models are ready. Poll the episodes audio asset state but
    # guard against waiting for episode assets that will never be processed.
    def self.wait_for_asset_state(api, eps)
      wait_for(eps, wait_timeout: EPISODE_ASSET_WAIT_TIMEOUT, wait_interval: EPISODE_ASSET_WAIT_INTERVAL) do |remaining_eps|
        Rails.logger.info("Probing for episode audio asset state")
        unwrapped = get_episodes(api, remaining_eps)

        remote_ep_by_id = unwrapped.map { |row| [row["request_metadata"]["guid"], row] }.to_h
        remaining_eps.each { |ep| upsert_sync_log(ep, remote_ep_by_id[ep.guid]) }

        remaining_eps.each do |ep|
          Rails.logger.info("Waiting for audio asset state?", {episode_id: ep.feeder_id,
                                                               delivery_file_count: ep.podcast_delivery_files.count,
                                                               delivery_files_processed_errors: ep.podcast_delivery_files.all?(&:processed_errors?),
                                                               delivery_files_processed: ep.podcast_delivery_files.all?(&:processed?),
                                                               delivery_files_delivered: ep.podcast_delivery_files.all?(&:delivered?),
                                                               asset_state: ep.audio_asset_state,
                                                               has_podcast_audio: ep&.podcast_container&.has_podcast_audio?,
                                                               waiting_for_asset_state: ep.waiting_for_asset_state?})
        end

        rem =
          remaining_eps.filter do |ep|
            if ep.waiting_for_asset_state?
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
      return [] if episodes.empty?

      api.bridge_remote_and_retry!("getEpisodes", episodes.map(&:get_episode_bridge_params))
    end

    def self.poll_episode_state(api, show, episodes)
      guid_to_apple_json = show.apple_episode_json.map do |ep_json|
        [ep_json["attributes"]["guid"], ep_json]
      end.to_h

      # Only sync episodes that have a remote pair
      episodes_to_sync = episodes.filter { |ep| guid_to_apple_json[ep.guid].present? }

      bridge_params = episodes_to_sync.map do |ep|
        id = guid_to_apple_json[ep.guid]["id"]
        guid = guid_to_apple_json[ep.guid]["attributes"]["guid"]
        Episode.get_episode_bridge_params(api, id, guid)
      end

      results = api.bridge_remote_and_retry!("getEpisodes", bridge_params)

      join_on("guid", episodes_to_sync, results).map do |(ep, row)|
        upsert_sync_log(ep, row)
      end
    end

    def self.create_episodes(api, episodes)
      return if episodes.empty?

      results = api.bridge_remote_and_retry!("createEpisodes",
        episodes.map(&:create_episode_bridge_params), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE)

      join_on("guid", episodes, results).map do |(ep, row)|
        upsert_sync_log(ep, row)
      end
    end

    def self.update_episodes(api, episodes)
      return if episodes.empty?

      episode_bridge_results = api.bridge_remote_and_retry!("updateEpisodes",
        episodes.map(&:update_episode_bridge_params), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE)

      upsert_sync_logs(episodes, episode_bridge_results)
    end

    def self.update_audio_container_reference(api, episodes)
      return [] if episodes.empty?

      # Make sure that we only update episodes that have a podcast container
      # And that the episode needs to be updated
      episodes = episodes.filter { |ep| ep.has_unlinked_container? }

      (episode_bridge_results, errs) =
        api.bridge_remote_and_retry(
          "updateEpisodes",
          episodes.map(&:update_episode_audio_container_bridge_params)
        )

      upsert_sync_logs(episodes, episode_bridge_results)

      api.raise_bridge_api_error(errs) if errs.present?

      episode_bridge_results
    end

    def self.remove_audio_container_reference(api, show, episodes, apple_mark_for_reupload: true)
      return [] if episodes.empty?

      (episode_bridge_results, errs) =
        api.bridge_remote_and_retry(
          "updateEpisodes",
          episodes.map(&:remove_episode_audio_container_bridge_params)
        )

      upsert_sync_logs(episodes, episode_bridge_results)

      join_on_apple_episode_id(episodes, episode_bridge_results).each do |(ep, row)|
        ep.feeder_episode.apple_mark_for_reupload if apple_mark_for_reupload
        Rails.logger.info("Removed audio container reference for episode", {episode_id: ep.feeder_id})
      end

      show.reload

      api.raise_bridge_api_error(errs) if errs.present?

      episode_bridge_results
    end

    def self.publish(api, show, episodes, state: "PUBLISH")
      return [] if episodes.empty?

      api.bridge_remote_and_retry!("publishEpisodes",
        episodes.map { |e| e.publishing_state_bridge_params(state) })

      # We don't get back the full episode model in the response.
      # So poll for current state
      poll_episode_state(api, show, episodes)
    end

    def self.upsert_sync_logs(episodes, results)
      episodes_by_guid = episodes.map { |ep| [ep.guid, ep] }.to_h

      results.map do |res|
        upsert_sync_log(episodes_by_guid[res.dig("request_metadata", "guid")], res)
      end
    end

    def self.upsert_sync_log(ep, res)
      apple_id = res.dig("api_response", "val", "data", "id")
      raise "Missing remote apple id" unless apple_id.present?

      sl = SyncLog.log!(feeder_id: ep.feeder_episode.id, feeder_type: :episodes, external_id: apple_id, api_response: res)
      # reload local state
      if ep.feeder_episode.apple_sync_log.nil?
        ep.feeder_episode.reload
      else
        ep.feeder_episode.apple_sync_log.reload
      end
      sl
    end

    def initialize(show:, feeder_episode:, api:)
      @show = show
      @feeder_episode = feeder_episode
      @api = api || Apple::Api.from_env
    end

    def api_response
      feeder_episode.apple_sync_log&.api_response
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
      uri = URI.parse(enclosure_url)
      File.basename(uri.path)
    end

    def sync_log
      SyncLog.episodes.find_by(feeder_id: feeder_episode.id, feeder_type: :episodes)
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
        request_metadata: {
          guid: guid
        },
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
            description: feeder_episode.description_with_default,
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

    def update_episode_bridge_params
      {
        request_metadata: {
          apple_episode_id: apple_id,
          guid: guid
        },
        api_url: api.join_url("episodes/#{apple_id}").to_s,
        api_parameters: episode_update_parameters
      }
    end

    def episode_update_parameters
      create_params = episode_create_parameters
      create_params[:data][:id] = apple_id
      create_params[:data].delete(:relationships)
      create_params[:data][:attributes].delete(:guid)

      ep_attrs = create_params[:data][:attributes]
      ep_attrs = ep_attrs.merge(apple_episode_update_attributes || {})

      create_params[:data][:attributes] = ep_attrs
      create_params
    end

    def update_episode_audio_container_bridge_params
      {
        request_metadata: {
          apple_episode_id: apple_id,
          guid: guid
        },
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

    def remove_episode_audio_container_bridge_params
      {
        request_metadata: {
          apple_episode_id: apple_id,
          guid: guid
        },
        api_url: api.join_url("episodes/#{apple_id}").to_s,
        api_parameters: remove_episode_audio_container_parameters
      }
    end

    def remove_episode_audio_container_parameters
      {
        data:
        {
          type: "episodes",
          id: apple_id,
          attributes: {
            appleHostedAudioAssetContainerId: nil
          }
        }
      }
    end

    def publishing_state_bridge_params(state)
      {
        api_url: api.join_url("episodePublishingRequests").to_s,
        api_parameters: publishing_state_parameters(state)
      }
    end

    def publishing_state_parameters(state)
      {
        data: {
          type: "episodePublishingRequests",
          attributes: {
            action: state
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

    def container_upload_complete?
      return false if missing_container?

      podcast_container.container_upload_satisfied?
    end

    def audio_asset_vendor_id
      apple_attributes["appleHostedAudioAssetVendorId"]
    end

    def apple_hosted_audio_asset_container_id
      apple_attributes["appleHostedAudioAssetContainerId"]
    end

    def audio_asset_state
      return nil unless api_response.present?

      apple_attributes["appleHostedAudioAssetState"]
    end

    def has_container?
      podcast_container.present?
    end

    def missing_container?
      !has_container?
    end

    def has_unlinked_container?
      has_container? && apple_hosted_audio_asset_container_id.blank?
    end

    def has_linked_container?
      has_container? && apple_hosted_audio_asset_container_id.present?
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

    def reset_for_upload!
      container.podcast_deliveries.each(&:destroy)
      feeder_episode.reload
    end

    def synced_with_apple?
      audio_asset_state_success? && container_upload_complete? && !drafting?
    end

    def waiting_for_asset_state?
      podcast_container.delivery_settled? && !audio_asset_state_finished?
    end

    def apple_id
      apple_json&.dig("id")
    end

    def apple_episode_id
      apple_id
    end

    def video_content_type?
      feeder_episode.video_content_type?
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

    alias_method :container, :podcast_container
    alias_method :deliveries, :podcast_deliveries
    alias_method :delivery_files, :podcast_delivery_files

    def apple_sync_log
      feeder_episode.apple_sync_log
    end

    def apple_sync_log=(sl)
      feeder_episode.apple_sync_log = sl
    end
  end
end
