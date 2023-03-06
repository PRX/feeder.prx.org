# frozen_string_literal: true

module Apple
  class Publisher
    attr_reader :public_feed,
      :private_feed,
      :api,
      :show

    def self.from_apple_config(apple_config)
      api = Apple::Api.from_apple_config(apple_config)

      new(api: api,
        public_feed: apple_config.public_feed,
        private_feed: apple_config.private_feed)
    end

    def initialize(api:, public_feed:, private_feed:)
      @public_feed = public_feed
      @private_feed = private_feed
      @api = api
      @show = Apple::Show.new(api: api,
        public_feed: public_feed,
        private_feed: private_feed)
    end

    def podcast
      public_feed.podcast
    end

    def episodes_to_sync
      @episodes_to_sync ||= show.episodes
    end

    def poll!
      if show.apple_id.nil?
        Rails.logger.warn "No connected Apple Podcasts show. Skipping polling!", {public_feed_id: public_feed.id,
                                                                                  private_feed_id: private_feed.id,
                                                                                  podcast_id: podcast.id}
        return
      end

      poll_episodes!
      poll_podcast_containers!
      poll_podcast_deliveries!
      poll_podcast_delivery_files!
    end

    def publish!
      show.sync!
      raise "Missing Show!" unless show.apple_id.present?

      # only create if needed
      sync_episodes!
      sync_podcast_containers!
      sync_podcast_deliveries!
      sync_podcast_delivery_files!

      # upload and mark as uploaded
      execute_upload_operations!
      mark_delivery_files_uploaded!

      wait_for_upload_processing
      wait_for_asset_state

      publish_drafting!

      log_delivery_processing_errors

      # success
      SyncLog.create!(feeder_id: public_feed.id, feeder_type: :feeds, external_id: show.apple_id)
    end

    def log_delivery_processing_errors
      episodes_to_sync.each do |ep|
        ep.podcast_delivery_files.each do |pdf|
          next unless pdf.processed_errors?

          Rails.logger.error("Episode has processing errors",
            {episode_id: ep.feeder_id,
             podcast_delivery_file_id: pdf.id,
             assert_processing_state: pdf.asset_processing_state,
             asset_delivery_state: pdf.asset_delivery_state})
        end
      end

      true
    end

    def wait_for_upload_processing
      pdfs = episodes_to_sync.map(&:podcast_delivery_files).flatten

      Apple::PodcastDeliveryFile.wait_for_delivery_files(api, pdfs)
    end

    def wait_for_asset_state
      eps = episodes_to_sync.filter { |e| e.podcast_delivery_files.any?(&:api_marked_as_uploaded?) }
      Apple::Episode.wait_for_asset_state(api, eps)
    end

    def poll_episodes!
      local_episodes = episodes_to_sync

      local_guids = local_episodes.map(&:guid)
      remote_guids = show.apple_episode_guids

      Rails.logger.info("Polling remote / local episode state", {local_count: local_guids.length,
                                                                  remote_count: remote_guids.length,
                                                                  local_missing_remote: local_guids - remote_guids,
                                                                  remote_missing_local: remote_guids - local_guids})
    end

    def sync_episodes!
      Rails.logger.info("Starting podcast episode sync")

      create_apple_episodes = episodes_to_sync.select(&:apple_new?)
      # NOTE: We don't attempt to update the remote state of episodes. Once
      # apple has parsed the feed, it will not allow changing any attributes.
      #
      # It's assumed that the episodes are created solely by the PRX web UI (not
      # on Podcasts Connect).
      Apple::Episode.create_episodes(api, create_apple_episodes)

      Rails.logger.info("Created remote episodes", {count: create_apple_episodes.length})

      show.reload
    end

    def poll_podcast_containers!
      res = Apple::PodcastContainer.poll_podcast_container_state(api, episodes_to_sync)
      Rails.logger.info("Modified local state for podcast containers.", {count: res.length})
    end

    def sync_podcast_containers!
      # TODO: right now we only create one delivery per container,
      # Apple RSS scaping means we don't need deliveries for freemium episode images
      # But we do need asset deliveries for apple-only (non-rss) images

      Rails.logger.info("Starting podcast container sync")

      poll_podcast_containers!

      res = Apple::PodcastContainer.create_podcast_containers(api, episodes_to_sync)
      Rails.logger.info("Created remote and local state for podcast containers.", {count: res.length})

      res = Apple::Episode.update_audio_container_reference(api, episodes_to_sync)
      Rails.logger.info("Updated remote container references for episodes.", {count: res.length})

      res = Apple::PodcastContainer.update_podcast_container_file_metadata(api, episodes_to_sync)
      Rails.logger.info("Updated remote file metadata on podcast containers.", {count: res.length})
    end

    def poll_podcast_deliveries!
      res = Apple::PodcastDelivery.poll_podcast_deliveries_state(api, episodes_to_sync)
      Rails.logger.info("Modified local state for podcast deliveries.", {count: res.length})
    end

    def sync_podcast_deliveries!
      Rails.logger.info("Starting podcast deliveries sync")

      poll_podcast_deliveries!

      res = Apple::PodcastDelivery.create_podcast_deliveries(api, episodes_to_sync)
      Rails.logger.info("Created remote and local state for podcast deliveries.", {count: res.length})
    end

    def poll_podcast_delivery_files!
      res = Apple::PodcastDeliveryFile.poll_podcast_delivery_files_state(api, episodes_to_sync)
      Rails.logger.info("Modified local state for podcast delivery files.", {count: res.length})
    end

    def sync_podcast_delivery_files!
      Rails.logger.info("Starting podcast delivery files sync")

      poll_podcast_delivery_files!

      res = Apple::PodcastDeliveryFile.create_podcast_delivery_files(api, episodes_to_sync)
      Rails.logger.info("Created remote/local state for #{res.length} podcast delivery files.")
    end

    def execute_upload_operations!
      Apple::UploadOperation.execute_upload_operations(api, episodes_to_sync)
    end

    def mark_delivery_files_uploaded!
      pdfs = episodes_to_sync.map(&:podcast_delivery_files).flatten
      ::Apple::PodcastDeliveryFile.mark_uploaded(api, pdfs)
    end

    def publish_drafting!
      eps = episodes_to_sync.select { |ep| ep.drafting? && ep.apple_upload_complete? }

      res = Apple::Episode.publish(api, eps)
      Rails.logger.info("Published #{res.length} drafting episodes.")
    end
  end
end
