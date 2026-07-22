# frozen_string_literal: true

module Apple
  class Episode < Integrations::Base::Episode
    include Apple::ApiResponse
    attr_accessor :show,
      :feeder_episode,
      :api,
      :episode_update_attributes

    delegate :media_version_id, :podcast_id, to: :feeder_episode

    AUDIO_ASSET_FAILURE = "FAILURE"
    AUDIO_ASSET_SUCCESS = "SUCCESS"

    # Cleans up old delivery/delivery files iff the episode is to be uploaded
    def self.prepare_for_delivery(episodes)
      episodes.map do |ep|
        Rails.logger.info("Preparing episode #{ep.feeder_id} for delivery", {episode_id: ep.feeder_id})
        ep.prepare_for_delivery!

        ep
      end
    end

    def self.probe_asset_state(api, episodes)
      Rails.logger.info("Probing for episode audio asset state")
      unwrapped = get_episodes(api, episodes)

      remote_ep_by_id = unwrapped.map { |row| [row["request_metadata"]["feeder_id"], row] }.to_h
      episodes.each { |ep| upsert_sync_log(ep, remote_ep_by_id[ep.id]) }

      ready = episodes.reject(&:waiting_for_asset_state?)
      waiting = episodes.select(&:waiting_for_asset_state?)

      [ready, waiting]
    end

    def self.get_episodes(api, episodes)
      return [] if episodes.empty?

      api.bridge_remote_and_retry!("getEpisodes", episodes.map(&:get_episode_bridge_params))
    end

    # Creates the `#sync_log` attributes for the given episodes
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

      Apple::ApiJoin.join_on("feeder_id", episodes_to_sync, results).map do |(ep, row)|
        upsert_sync_log(ep, row)
      end
    end

    def self.create_episodes(api, episodes)
      return if episodes.empty?

      results = api.bridge_remote_and_retry!("createEpisodes",
        episodes.map(&:create_episode_bridge_params), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE)

      Apple::ApiJoin.join_on("guid", episodes, results).map do |(ep, row)|
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

    def self.remove_audio_container_reference(api, show, episodes, mark_as_not_delivered: true)
      return [] if episodes.empty?

      (episode_bridge_results, errs) =
        api.bridge_remote_and_retry(
          "updateEpisodes",
          episodes.map(&:remove_episode_audio_container_bridge_params)
        )

      upsert_sync_logs(episodes, episode_bridge_results)

      Apple::ApiJoin.join_on_apple_episode_id(episodes, episode_bridge_results).each do |(ep, row)|
        ep.mark_as_not_delivered! if mark_as_not_delivered
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

      Apple::ApiJoin.join_on_apple_episode_id(episodes, episode_bridge_results).each do |(ep, row)|
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
      apple_show_id = ep.apple_show_id.presence || raise(MissingShowIdentityError, "Apple sync state requires an Apple show ID")

      sl = SyncLog.log!(
        integration: :apple,
        feeder_id: ep.feeder_episode.id,
        feeder_type: :episodes,
        external_id: apple_id,
        api_response: res,
        apple_show_id: apple_show_id
      )
      # reload local state
      ep.sync_log&.reload || ep.feeder_episode.reload
      sl
    end

    def initialize(show:, feeder_episode:, api:)
      @show = show
      @feeder_episode = feeder_episode
      @api = api || Apple::Api.from_env
    end

    def synced_with_integration?
      audio_asset_state_success? && has_delivery? && !drafting?
    end
    alias_method :synced_with_apple?, :synced_with_integration?

    def integration_new?
      apple_json.blank?
    end
    alias_method :apple_new?, :integration_new?

    def api_response
      sync_log&.api_response
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
      show_id = scoped_apple_show_id!
      logs = SyncLog.apple.episodes.where(feeder_id: feeder_episode.id, feeder_type: :episodes)

      # TODO remove with cutover once all legacy NULL-show rows are stamped.
      logs.find_by(apple_show_id: show_id) || logs.find_by(apple_show_id: nil)
    end

    def apple_show_id
      show.id if show.respond_to?(:id)
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
            title: feeder_episode.title_safe,
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
      ep_attrs = ep_attrs.merge(episode_update_attributes || {})

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

    def delivery_file_errors?
      podcast_delivery_files.any?(&:processed_errors?)
    end

    def error_state?
      audio_asset_state_error? || delivery_file_errors?
    end

    def audio_asset_state_success?
      audio_asset_state == AUDIO_ASSET_SUCCESS
    end

    def needs_delivery?
      return true if missing_container?

      podcast_container&.needs_delivery? || needs_delivery_processing? || needs_media_version?
    end

    def has_delivery?
      !needs_delivery?
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
      show_id = scoped_apple_show_id!
      containers = Apple::PodcastContainer.where(episode_id: feeder_id)
      # TODO remove with cutover after all legacy NULL-show rows are stamped.
      containers.find_by(apple_show_id: show_id) || containers.find_by(apple_show_id: nil)
    end

    def podcast_deliveries
      podcast_container&.podcast_deliveries || Apple::PodcastDelivery.none
    end

    def podcast_delivery_files
      podcast_container&.podcast_delivery_files || Apple::PodcastDeliveryFile.none
    end

    def mark_as_not_delivered!
      update_delivery_status(delivered: false, uploaded: false, asset_processing_attempts: 0)
    end

    def mark_as_delivered!
      update_delivery_status(delivered: true, uploaded: true, asset_processing_attempts: 0)
    end

    def update_delivery_status(attrs)
      Apple::EpisodeDeliveryStatus.update_status(feeder_episode, attrs, apple_show_id: scoped_apple_show_id!)
    end

    def delivery_status(_with_default = true)
      Apple::EpisodeDeliveryStatus.current_or_default(feeder_episode, apple_show_id: scoped_apple_show_id!)
    end

    def delivery_statuses
      show_id = scoped_apple_show_id!

      # TODO remove with cutover after all legacy NULL-show rows are stamped.
      Apple::EpisodeDeliveryStatus
        .where(episode_id: feeder_id, apple_show_id: [show_id, nil])
        .order(created_at: :desc)
    end

    # The aggregate #needs_delivery? predicate answers whether any delivery work
    # remains. This narrower predicate gates the Publisher#process_delivery!
    # phase after any necessary upload has completed.
    def needs_delivery_processing?
      delivery_status.delivered == false
    end

    def needs_upload?
      delivery_status.needs_upload?
    end

    def prepare_for_delivery!
      podcast_deliveries.each(&:destroy)
      podcast_deliveries.reset
      podcast_delivery_files.reset
      podcast_container&.podcast_deliveries&.reset
      mark_as_not_delivered!
    end

    def measure_asset_processing_duration
      Integrations::EpisodeDeliveryStatus.measure_asset_processing_duration(delivery_statuses)
    end

    alias_method :container, :podcast_container
    alias_method :deliveries, :podcast_deliveries
    alias_method :delivery_files, :podcast_delivery_files

    private

    def scoped_apple_show_id!
      apple_show_id.presence || raise(MissingShowIdentityError, "Apple state requires an Apple show ID")
    end
  end
end
