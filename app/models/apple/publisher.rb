# frozen_string_literal: true

module Apple
  class Publisher
    PUBLISH_CHUNK_LEN = 25

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
      show.episodes
    end

    def poll!(eps = episodes_to_sync)
      if show.apple_id.nil?
        Rails.logger.warn "No connected Apple Podcasts show. Skipping polling!", {public_feed_id: public_feed.id,
                                                                                  private_feed_id: private_feed.id,
                                                                                  podcast_id: podcast.id}
        return
      end

      Rails.logger.tagged("Apple::Publisher#poll!") do
        # Reject episodes if the audio is marked as uploaded/complete
        eps = eps.reject(&:synced_with_apple?)

        eps.each_slice(PUBLISH_CHUNK_LEN) do |eps|
          poll_episodes!(eps)
          poll_podcast_containers!(eps)
          poll_podcast_deliveries!(eps)
          poll_podcast_delivery_files!(eps)
        end
      end
    end

    def publish!(eps = episodes_to_sync)
      show.sync!
      raise "Missing Show!" unless show.apple_id.present?

      Rails.logger.tagged("Apple::Publisher#publish!") do
        # Reject episodes if the audio is marked as uploaded/complete
        eps = eps.reject(&:synced_with_apple?)

        eps.each_slice(PUBLISH_CHUNK_LEN) do |eps|
          # only create if needed
          sync_episodes!(eps)
          sync_podcast_containers!(eps)
          sync_podcast_deliveries!(eps)
          sync_podcast_delivery_files!(eps)

          # upload and mark as uploaded
          execute_upload_operations!(eps)
          mark_delivery_files_uploaded!(eps)

          wait_for_upload_processing(eps)
          wait_for_asset_state(eps)

          publish_drafting!(eps)

          log_delivery_processing_errors(eps)
        end
      end

      # success
      SyncLog.log!(feeder_id: public_feed.id, feeder_type: :feeds, external_id: show.apple_id, api_response: {success: true})
    end

    def log_delivery_processing_errors(eps)
      eps.each do |ep|
        ep.podcast_delivery_files.each do |pdf|
          next unless pdf.processed_errors?

          Rails.logger.error("Episode has processing errors",
            {episode_id: ep.feeder_id,
             podcast_delivery_file_id: pdf.id,
             asset_processing_state: pdf.asset_processing_state,
             asset_delivery_state: pdf.asset_delivery_state})
        end
      end

      true
    end

    def wait_for_upload_processing(eps)
      Rails.logger.tagged("##{__method__}") do
        pdfs = eps.map(&:podcast_delivery_files).flatten

        Apple::PodcastDeliveryFile.wait_for_delivery_files(api, pdfs)
      end
    end

    def wait_for_asset_state(eps)
      Rails.logger.tagged("##{__method__}") do
        eps = eps.filter { |e| e.podcast_delivery_files.any?(&:api_marked_as_uploaded?) }
        Apple::Episode.wait_for_asset_state(api, eps)
      end
    end

    def poll_episodes!(eps)
      Rails.logger.tagged("##{__method__}") do
        res = Apple::Episode.poll_episode_state(api, show, eps)

        Rails.logger.info("Polling remote / local episode state", {local_count: eps.length,
                                                                    remote_count: res.length})

        eps
      end
    end

    def sync_episodes!(eps)
      Rails.logger.tagged("##{__method__}") do
        Rails.logger.info("Starting podcast episode sync")
        poll_episodes!(eps)

        create_apple_episodes = eps.select(&:apple_new?)
        # NOTE: We don't attempt to update the remote state of episodes. Once
        # apple has parsed the feed, it will not allow changing any attributes.
        #
        # It's assumed that the episodes are created solely by the PRX web UI (not
        # on Podcasts Connect).
        Apple::Episode.create_episodes(api, create_apple_episodes)

        Rails.logger.info("Created remote episodes", {count: create_apple_episodes.length})

        show.reload
      end
    end

    def poll_podcast_containers!(eps)
      Rails.logger.tagged("##{__method__}") do
        res = Apple::PodcastContainer.poll_podcast_container_state(api, eps)
        Rails.logger.info("Modified local state for podcast containers.", {count: res.length})
      end
    end

    def sync_podcast_containers!(eps)
      Rails.logger.tagged("##{__method__}") do
        # TODO: right now we only create one delivery per container,
        # Apple RSS scaping means we don't need deliveries for freemium episode images
        # But we do need asset deliveries for apple-only (non-rss) images

        Rails.logger.info("Starting podcast container sync")

        poll_podcast_containers!(eps)

        # The podcast container is storing the metadata for the audio file
        # (size, url, etc).
        # The 'reset' in this case means fetching new CDN urls for the audio and
        # making sure that we will HEAD their file sizes for later upload.
        # Only reset if we need delivery.
        reset = Apple::PodcastContainer.reset_source_urls(api, eps)
        Rails.logger.info("Reset podcast containers for expired source urls.", {reset_count: reset.length})

        res = Apple::PodcastContainer.create_podcast_containers(api, eps)
        Rails.logger.info("Created remote and local state for podcast containers.", {count: res.length})

        res = Apple::Episode.update_audio_container_reference(api, eps)
        Rails.logger.info("Updated remote container references for episodes.", {count: res.length})

        res = Apple::PodcastContainer.update_podcast_container_file_metadata(api, eps)
        Rails.logger.info("Updated remote file metadata on podcast containers.", {count: res.length})
      end
    end

    def poll_podcast_deliveries!(eps)
      Rails.logger.tagged("##{__method__}") do
        res = Apple::PodcastDelivery.poll_podcast_deliveries_state(api, eps)
        Rails.logger.info("Modified local state for podcast deliveries.", {count: res.length})
      end
    end

    def sync_podcast_deliveries!(eps)
      Rails.logger.tagged("##{__method__}") do
        Rails.logger.info("Starting podcast deliveries sync")

        poll_podcast_deliveries!(eps)

        res = Apple::PodcastDelivery.create_podcast_deliveries(api, eps)
        Rails.logger.info("Created remote and local state for podcast deliveries.", {count: res.length})
      end
    end

    def poll_podcast_delivery_files!(eps)
      Rails.logger.tagged("##{__method__}") do
        res = Apple::PodcastDeliveryFile.poll_podcast_delivery_files_state(api, eps)
        Rails.logger.info("Modified local state for podcast delivery files.", {count: res.length})
      end
    end

    def sync_podcast_delivery_files!(eps)
      Rails.logger.tagged("##{__method__}") do
        Rails.logger.info("Starting podcast delivery files sync")

        # TODO
        poll_podcast_delivery_files!(eps)

        res = Apple::PodcastDeliveryFile.create_podcast_delivery_files(api, eps)
        Rails.logger.info("Created remote/local state for #{res.length} podcast delivery files.")
      end
    end

    def execute_upload_operations!(eps)
      Rails.logger.tagged("##{__method__}") do
        Apple::UploadOperation.execute_upload_operations(api, eps)
      end
    end

    def mark_delivery_files_uploaded!(eps)
      Rails.logger.tagged("##{__method__}") do
        pdfs = eps.map(&:podcast_delivery_files).flatten
        ::Apple::PodcastDeliveryFile.mark_uploaded(api, pdfs)
      end
    end

    def publish_drafting!(eps)
      Rails.logger.tagged("##{__method__}") do
        eps = eps.select { |ep| ep.drafting? && ep.apple_upload_complete? }

        res = Apple::Episode.publish(api, eps)
        Rails.logger.info("Published #{res.length} drafting episodes.")
      end
    end
  end
end
