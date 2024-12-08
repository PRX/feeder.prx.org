# frozen_string_literal: true

module Apple
  class Episode < Integrations::Base::Episode
    include Apple::ApiWaiting
    include Apple::ApiResponse
    attr_accessor :show,
      :feeder_episode,
      :api,
      :apple_episode_update_attributes

    AUDIO_ASSET_FAILURE = "FAILURE"
    AUDIO_ASSET_SUCCESS = "SUCCESS"

    EPISODE_ASSET_WAIT_TIMEOUT = 15.minutes.freeze
    EPISODE_ASSET_WAIT_INTERVAL = 10.seconds.freeze

    # Cleans up old delivery/delivery files iff the episode is to be uploaded
    def self.prepare_for_delivery(episodes)
      episodes.map do |ep|
        Rails.logger.info("Preparing episode #{ep.feeder_id} for delivery", {episode_id: ep.feeder_id})
        ep.feeder_episode.apple_prepare_for_delivery!

        ep
      end
    end

    # In the case where the episodes state is not yet ready to publish, but the
    # underlying models are ready. Poll the episodes audio asset state but
    # guard against waiting for episode assets that will never be processed.
    def self.wait_for_asset_state(api, eps)
      wait_for(eps, wait_timeout: EPISODE_ASSET_WAIT_TIMEOUT, wait_interval: EPISODE_ASSET_WAIT_INTERVAL) do |remaining_eps|
        Rails.logger.info("Probing for episode audio asset state")
        unwrapped = get_episodes(api, remaining_eps)

        remote_ep_by_id = unwrapped.map { |row| [row["request_metadata"]["feeder_id"], row] }.to_h
        remaining_eps.each { |ep| upsert_sync_log(ep, remote_ep_by_id[ep.id]) }

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

    # Creates the `#apple_sync_log` attributes for the given episodes
    # and returns the created `SyncLog` records
    # This indicates that there is a remote pair for the episode
    def self.poll_episode_state(api, show, episodes)
      # Only sync episodes that have a remote pair
      episodes_to_sync = episodes.filter { |ep| show.find_apple_episode_json_by_guid(ep.guid).present? }

      bridge_params = episodes_to_sync.map do |ep|
        apple_json = show.find_apple_episode_json_by_guid(ep.guid)
        apple_episode_id = apple_json["id"]
        Episode.get_episode_bridge_params(api, ep.feeder_id, apple_episode_id)
      end

      results = api.bridge_remote_and_retry!("getEpisodes", bridge_params)

      join_on("feeder_id", episodes_to_sync, results).map do |(ep, row)|
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

      (episode_bridge_results, errs) =
        api.bridge_remote_and_retry("updateEpisodes",
          episodes.map(&:update_episode_bridge_params), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE, ignore_errors: [Apple::Api::CONFLICT])

      errs.each do |err|
        Rails.logger.warn("Error updating episode", {error: err})
      end

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
        ep.feeder_episode.apple_mark_for_reupload! if apple_mark_for_reupload
        Rails.logger.info("Removed audio container reference for episode", {episode_id: ep.feeder_id})
      end

      show.reload

      api.raise_bridge_api_error(errs) if errs.present?

      episode_bridge_results
    end

    def self.archive(api, show, episodes)
      res = alter_publish_state(api, show, episodes, "ARCHIVE")
      # Apple purges the podcast deliveries when you archive/unarchive an episode
      episodes.map(&:podcast_deliveries).flatten.each(&:destroy)

      res
    end

    def self.unarchive(api, show, episodes)
      res = alter_publish_state(api, show, episodes, "UNARCHIVE")
      # Apple purges the podcast deliveries when you archive/unarchive an episode
      episodes.map(&:podcast_deliveries).flatten.each(&:destroy)

      res
    end

    def self.publish(api, show, episodes)
      alter_publish_state(api, show, episodes, "PUBLISH")
    end

    def self.alter_publish_state(api, show, episodes, state)
      return [] if episodes.empty?

      episode_bridge_results = api.bridge_remote_and_retry!("publishEpisodes",
        episodes.map { |e| e.publishing_state_bridge_params(state) })

      join_on_apple_episode_id(episodes, episode_bridge_results).each do |(ep, row)|
        Rails.logger.info("Moving episode to #{state} state", {episode_id: ep.feeder_id, state: ep.publishing_state})
      end

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

      sl = SyncLog.log!(
        integration: :apple,
        feeder_id: ep.feeder_episode.id,
        feeder_type: :episodes,
        external_id: apple_id,
        api_response: res
      )
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

    def synced_with_integration?
      synced_with_apple?
    end

    def integration_new?
      apple_new?
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

    def id
      feeder_id
    end

    def private_feed
      show.private_feed
    end

    def podcast
      show.podcast
    end

    def enclosure_url
      url = EnclosureUrlBuilder.new.base_enclosure_url(podcast, feeder_episode, private_feed)
      EnclosureUrlBuilder.mark_authorized(url, private_feed)
    end

    def enclosure_filename
      uri = URI.parse(enclosure_url)
      File.basename(uri.path)
    end

    def sync_log
      SyncLog.apple.episodes.find_by(feeder_id: feeder_episode.id, feeder_type: :episodes)
    end

    def self.get_episode_bridge_params(api, feeder_id, apple_id)
      {
        request_metadata: {
          apple_episode_id: apple_id,
          feeder_id: feeder_id
        },
        api_url: api.join_url("episodes/#{apple_id}").to_s,
        api_parameters: {}
      }
    end

    def get_episode_bridge_params
      self.class.get_episode_bridge_params(api, feeder_id, apple_id)
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
            description: feeder_episode.description_safe,
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
      self.class.publishing_state_bridge_params(apple_id, state)
    end

    def self.publishing_state_bridge_params(apple_id, state)
      {
        request_metadata: {
          apple_episode_id: apple_id
        },
        api_url: Apple::Api.join_url("episodePublishingRequests").to_s,
        api_parameters: publishing_state_params(apple_id, state)
      }
    end

    def self.publishing_state_params(apple_id, state)
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

    def publishing_state_parameters(state)
      self.class.publishing_state_params(apple_id, state)
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

    def publishing_state
      apple_json&.dig("attributes", "publishingState")
    end

    def drafting?
      publishing_state == "DRAFTING"
    end

    def archived?
      publishing_state == "ARCHIVED"
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

    def needs_delivery?
      return true if missing_container?

      podcast_container&.needs_delivery? || feeder_episode.apple_needs_delivery? || needs_media_version?
    end

    def has_delivery?
      !needs_delivery?
    end

    def synced_with_apple?
      audio_asset_state_success? && has_delivery? && !drafting?
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

    def apple_sync_log
      feeder_episode.apple_sync_log
    end

    def apple_sync_log=(sl)
      feeder_episode.apple_sync_log = sl
    end

    def apple_mark_for_reupload!
      feeder_episode.apple_mark_for_reupload!
    end

    def apple_episode_delivery_status
      feeder_episode.apple_episode_delivery_status
    end

    def apple_episode_delivery_statuses
      feeder_episode.apple_episode_delivery_statuses
    end

    alias_method :container, :podcast_container
    alias_method :deliveries, :podcast_deliveries
    alias_method :delivery_files, :podcast_delivery_files
    alias_method :delivery_status, :apple_episode_delivery_status
    alias_method :delivery_statuses, :apple_episode_delivery_statuses
    alias_method :apple_status, :apple_episode_delivery_status

    # Delegate methods to feeder_episode
    def method_missing(method_name, *arguments, &block)
      if feeder_episode.respond_to?(method_name)
        feeder_episode.send(method_name, *arguments, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      feeder_episode.respond_to?(method_name) || super
    end
  end
end
