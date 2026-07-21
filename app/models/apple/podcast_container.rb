# frozen_string_literal: true

module Apple
  class PodcastContainer < ApplicationRecord
    include Apple::ApiResponse

    serialize :api_response, coder: JSON

    default_scope { includes(:apple_sync_log) }

    has_one :apple_sync_log, -> { podcast_containers.apple }, foreign_key: :feeder_id, class_name: "Apple::SyncLog", dependent: :destroy
    has_many :podcast_deliveries, dependent: :destroy
    has_many :podcast_delivery_files, through: :podcast_deliveries
    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    # Existing legacy rows may be updated while the backfill is in progress,
    # but every newly created container must already be show-scoped.
    # TODO remove with cutover: validate every row and add the database constraint.
    validates :apple_show_id, presence: true, on: :create

    alias_method :deliveries, :podcast_deliveries
    alias_method :deliveries=, :podcast_deliveries=
    alias_method :delivery_files, :podcast_delivery_files
    alias_method :delivery_files=, :podcast_delivery_files=

    FILE_STATUS_SUCCESS = "In Asset Repository"
    FILE_ASSET_ROLE_PODCAST_AUDIO = "PodcastSourceAudio"
    SOURCE_URL_EXP_BUFFER = 10.minutes

    def self.poll_podcast_container_state(api, episodes, raise_on_reset: true)
      results = get_podcast_containers_via_episodes(api, episodes)
      stale_podcast_containers = []

      joined_rows = Apple::ApiJoin.join_on_apple_episode_id(episodes, results, left_join: true).each do |(ep, row)|
        if row.nil?
          if (container = ep.podcast_container)
            # Preserve the known-show context when a legacy container is
            # removed before the backfill has stamped it.
            # TODO remove with cutover after all legacy NULL-show rows are stamped.
            container.apple_show_id ||= ep.apple_show_id
            stale_podcast_containers << container
          end
          next
        end

        apple_id = row.dig("api_response", "val", "data", "id")
        raise "missing apple id!" unless apple_id.present?

        upsert_podcast_container(ep, row)
      end

      if stale_podcast_containers.any?
        if raise_on_reset
          reset_stale_podcast_containers_and_retry!(stale_podcast_containers)
        else
          # Poll-only callers (e.g. Apple::Publisher#poll!) have no publishing
          # pipeline to retry, so repair the local state and keep going.
          reset_stale_podcast_container_records!(stale_podcast_containers)
        end
      end

      joined_rows
    end

    def self.reset_stale_podcast_containers_and_retry!(containers)
      stale_podcast_containers = reset_stale_podcast_container_records!(containers)
      raise Apple::RetryPublishingError.new(
        "Reset #{stale_podcast_containers.length} stale Apple podcast containers"
      )
    end

    def self.reset_stale_podcast_container_records!(containers)
      stale_podcast_containers = containers.compact.uniq(&:id)

      stale_podcast_containers.each do |container|
        next if container.destroyed?

        episode = container.episode
        apple_show_id = container.apple_show_id

        Rails.logger.warn("Resetting stale Apple podcast container",
          feeder_episode_id: episode.id,
          apple_episode_id: container.apple_episode_id,
          podcast_container_id: container.id,
          vendor_id: container.vendor_id,
          external_id: container.external_id)

        container.destroy!
        episode.reload
        Apple::EpisodeDeliveryStatus.update_status(
          episode,
          {delivered: false, uploaded: false, asset_processing_attempts: 0},
          apple_show_id: apple_show_id
        )
      end

      stale_podcast_containers
    end

    def self.create_podcast_containers(api, episodes)
      # Apple has a 1:1 relationship between an Apple episode and its podcast
      # container. A feeder episode can belong to multiple Apple shows, so its
      # local containers are unique by feeder episode and Apple show.
      # We should have a local record of the podcast container, per the poll
      # method above.
      episodes_to_create = episodes.reject { |ep| ep.has_container? }

      new_containers_response =
        api.bridge_remote_and_retry!("createPodcastContainers",
          create_podcast_containers_bridge_params(api, episodes_to_create), batch_size: Api::DEFAULT_WRITE_BATCH_SIZE)

      Apple::ApiJoin.join_on_apple_episode_id(episodes_to_create, new_containers_response).each do |ep, row|
        upsert_podcast_container(ep, row)
      end

      episodes_to_create
    end

    def self.upsert_podcast_container(episode, row)
      apple_show_id = episode.apple_show_id.presence || raise(MissingShowIdentityError, "Apple container state requires an Apple show ID")
      external_id = row.dig("api_response", "val", "data", "id")
      raise "Missing external_id in response" if external_id.blank?

      attributes = {
        apple_episode_id: episode.apple_id,
        external_id: external_id,
        vendor_id: episode.audio_asset_vendor_id,
        apple_show_id: apple_show_id
      }
      pc, action = persist_podcast_container(episode.feeder_id, attributes)

      Rails.logger.info("#{action} local podcast container",
        {podcast_container_id: pc.id,
         action: action,
         external_id: external_id,
         feeder_episode_id: episode.feeder_id,
         apple_show_id: episode.apple_show_id})

      if pc.apple_sync_log
        pc.apple_sync_log.update!(external_id: external_id, api_response: row, updated_at: Time.now.utc)
      else
        SyncLog.log!(integration: :apple, feeder_id: pc.id, feeder_type: :podcast_containers, external_id: external_id, api_response: row)
      end

      # reset the episode's podcast container cached value
      pc.reload unless action == :created
      episode.feeder_episode.reload

      pc
    end

    def self.persist_podcast_container(episode_id, attributes)
      transaction do
        containers = where(episode_id: episode_id)
        pc = containers.lock.find_by(apple_show_id: attributes[:apple_show_id])
        # TODO remove with cutover after all legacy NULL-show rows are stamped.
        pc ||= containers.lock.find_by(apple_show_id: nil) if attributes[:apple_show_id].present?

        if pc
          action = (pc.apple_show_id.nil? && attributes[:apple_show_id].present?) ? :adopted : :updated
          pc.update!(attributes)
          pc.touch
          [pc, action]
        else
          [create!(attributes.merge(episode_id: episode_id)), :created]
        end
      end
    rescue ActiveRecord::RecordNotUnique
      # A concurrent upsert may have created the exact show-scoped row after
      # our lookup. The database constraint remains authoritative; only recover
      # when that exact row now exists, otherwise preserve the original error.
      pc = find_by(episode_id: episode_id, apple_show_id: attributes[:apple_show_id])
      raise unless pc

      pc.update!(attributes)
      pc.touch
      [pc, :updated]
    end
    private_class_method :persist_podcast_container

    def self.get_podcast_containers_via_episodes(api, episodes)
      # Fetch the podcast containers from the episodes side of the API
      response =
        api.bridge_remote_and_retry!("getPodcastContainers", get_podcast_containers_bridge_params(api, episodes), batch_size: 1)

      # Rather than mangling and persisting the enumerated view of the containers in the episodes,
      # just re-fetch the podcast containers from the non-list podcast container endpoint
      formatted_bridge_params = Apple::ApiJoin.join_on_apple_episode_id(episodes, response, left_join: true).flat_map do |(episode, row)|
        next [] if row.nil?

        get_urls_for_episode_podcast_containers(api, row).map do |url|
          get_podcast_containers_bridge_param(episode.apple_id, url)
        end
      end

      api.bridge_remote_and_retry!("getPodcastContainers", formatted_bridge_params, batch_size: 2)
    end

    def self.get_urls_for_episode_podcast_containers(api, episode_podcast_containers_json)
      containers_json = episode_podcast_containers_json["api_response"]["val"]["data"] || []
      if containers_json.length > 1
        apple_episode_id = episode_podcast_containers_json.dig("request_metadata", "apple_episode_id")
        raise "Unsupported number of podcast containers for episode: #{apple_episode_id}"
      end

      containers_json.map do |podcast_container_json|
        api.join_url("podcastContainers/#{podcast_container_json["id"]}").to_s
      end
    end

    def self.get_podcast_containers_bridge_params(api, episodes)
      episodes.map do |ep|
        get_podcast_containers_bridge_param(ep.apple_id, podcast_container_url(api, ep))
      end
    end

    def self.get_podcast_containers_bridge_param(apple_episode_id, api_url)
      {
        request_metadata: {apple_episode_id: apple_episode_id},
        api_url: api_url,
        api_parameters: {}
      }
    end

    def self.create_podcast_containers_bridge_params(api, episodes)
      episodes
        .map do |ep|
        {
          request_metadata: {apple_episode_id: ep.apple_id},
          api_url: api.join_url("podcastContainers").to_s,
          api_parameters: podcast_container_create_parameters(ep)
        }
      end
    end

    def self.podcast_container_create_parameters(episode)
      {
        data: {
          type: "podcastContainers",
          attributes: {
            vendorId: episode.audio_asset_vendor_id
          }
        }
      }
    end

    def self.podcast_containers_parameters(episode)
      {
        data: {
          type: "podcastContainers",
          attributes: {
            vendorId: episode.audio_asset_vendor_id,
            id: episode.podcast_container.external_id
          }
        }
      }
    end

    def self.podcast_container_url(api, episode)
      raise "Missing episode audio vendor id" unless episode.audio_asset_vendor_id.present?

      api.join_url("podcastContainers?filter[vendorId]=#{episode.audio_asset_vendor_id}").to_s
    end

    def head_file_size_bridge_params(enclosure_url:)
      {
        request_metadata: {
          apple_episode_id: apple_episode_id,
          podcast_container_id: id
        },
        api_url: enclosure_url,
        api_parameters: {}
      }
    end

    def podcast_deliveries_url
      apple_data.dig("relationships", "podcastDeliveries", "links", "related")
    end

    def podcast_container_id
      id
    end

    def files
      apple_attributes.dig("files")
    end

    def has_podcast_audio?
      return false if files.empty?

      files.all? do |file|
        # Retrieve the file status from the podcast container's files attribute
        file["status"] == FILE_STATUS_SUCCESS && file["assetRole"] == FILE_ASSET_ROLE_PODCAST_AUDIO
      end
    end

    def missing_podcast_audio?
      !has_podcast_audio?
    end

    def delivered?
      # because we cannot infer if the podcast delivery files have expired
      return true if podcast_delivery_files.length == 0

      podcast_delivery_files.all?(&:delivered?) &&
        podcast_delivery_files.all?(&:processed?)
    end

    def processed_errors?
      return false if podcast_delivery_files.length == 0

      podcast_delivery_files.all?(&:processed_errors?)
    end

    def delivery_settled?
      delivered? && !processed_errors?
    end

    def container_upload_satisfied?
      # Sets us up for a retry if something prevented the audio from being
      # marked as uploaded and then processed and validated. Assuming that we
      # get to that point and the audio is still missing, we should be able to
      # retry.
      has_podcast_audio?
    end

    def skip_delivery?
      container_upload_satisfied?
    end

    def needs_delivery?
      !skip_delivery?
    end
  end
end
