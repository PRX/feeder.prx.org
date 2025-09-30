module Apple
  class Publisher < Integrations::Base::Publisher
    include Apple::ApiWaiting
    attr_reader :public_feed,
      :private_feed,
      :api,
      :show

    EPISODE_ASSET_WAIT_TIMEOUT = 15.minutes.freeze
    EPISODE_ASSET_WAIT_INTERVAL = 10.seconds.freeze
    STUCK_EPISODE_TIMEOUT = 1.hour.freeze

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

      Rails.logger.info("Initialized Apple::Publisher", {public_feed_id: public_feed.id,
                                                         private_feed_id: private_feed.id,
                                                         podcast_id: podcast.id,
                                                         show_apple_id: show.apple_id})
    end

    def podcast
      public_feed.podcast
    end

    def poll_all_episodes!
      poll_episodes!(show.podcast_episodes)
    end

    def poll!(eps = episodes_to_sync)
      if show.apple_id.nil?
        Rails.logger.warn "No connected Apple Podcasts show. Skipping polling!", {public_feed_id: public_feed.id,
                                                                                  private_feed_id: private_feed.id,
                                                                                  podcast_id: podcast.id}
        return
      end

      Rails.logger.tagged("Apple::Publisher#poll!") do
        eps.each_slice(PUBLISH_CHUNK_LEN) do |eps|
          poll_episodes!(eps)

          eps = only_episodes_with_apple_state(eps)

          poll_podcast_containers!(eps)
          poll_podcast_deliveries!(eps)
          poll_podcast_delivery_files!(eps)
        end
      end
    end

    def publish!
      show.sync!
      raise "Missing Show!" unless show.apple_id.present?

      # Archive deleted or unpublished episodes.
      # These episodes are no longer in the private feed.
      poll_episodes!(episodes_to_archive)
      archive!(episodes_to_archive)

      # Un-archive episodes that are re-published.
      # These episodes are in the private feed.
      # Unarchived episodes are converted to "DRAFTING" state.
      poll_episodes!(episodes_to_unarchive)
      unarchive!(episodes_to_unarchive)

      # Calculate the episodes_to_sync based on the current state of the private feed
      upload_and_process!(episodes_to_sync)

      # success
      SyncLog.log!(
        integration: :apple,
        feeder_id: public_feed.id,
        feeder_type: :feeds,
        external_id: show.apple_id,
        api_response: {success: true}
      )
    end

    def upload_and_process!(eps)
      Rails.logger.tagged("Apple::Publisher#upload_and_process!") do
        eps.filter(&:apple_needs_upload?).each_slice(PUBLISH_CHUNK_LEN) do |eps|
          upload_media!(eps)
        end

        eps.filter(&:apple_needs_delivery?).each_slice(PUBLISH_CHUNK_LEN) do |eps|
          process_delivery!(eps)
        end

        eps.each_slice(PUBLISH_CHUNK_LEN) do |eps|
          publish_drafting!(eps)
          raise_delivery_processing_errors(eps)
        end
      end
    end

    def upload_media!(eps)
      # Soft delete any existing delivery and delivery files.
      prepare_for_delivery!(eps)

      # Only create if needed.
      sync_episodes!(eps)
      sync_podcast_containers!(eps)

      wait_for_versioned_source_metadata(eps)

      sync_podcast_deliveries!(eps)
      sync_podcast_delivery_files!(eps)

      # Upload and mark as uploaded, then update the audio container reference.
      execute_upload_operations!(eps)
      mark_delivery_files_uploaded!(eps)
      update_audio_container_reference!(eps)

      # Mark the episode as uploaded.
      mark_as_uploaded!(eps)

      # The episodes start waiting after they are uploaded.
      # Increment the wait counter.
      increment_asset_wait!(eps)
    end

    def process_delivery!(eps)
      increment_asset_wait!(eps)

      wait_for_upload_processing(eps)

      # Wait for the audio asset to be processed by Apple
      # Mark episodes as delivered as they are processed
      wait_for_asset_state(eps) do |ready_eps|
        mark_as_delivered!(ready_eps)
        reset_asset_wait!(ready_eps)
      end
    end

    def wait_for_asset_state(eps, wait_timeout: EPISODE_ASSET_WAIT_TIMEOUT, wait_interval: EPISODE_ASSET_WAIT_INTERVAL, &finisher_block)
      Rails.logger.tagged("##{__method__}") do
        remaining_eps = filter_episodes_awaiting_asset_state(eps)

        self.class.wait_for(remaining_eps,
          wait_timeout: wait_timeout,
          wait_interval: wait_interval) do |waiting_eps|
          ready_episodes, still_waiting_episodes = partition_episodes_by_readiness(waiting_eps)

          if ready_episodes.any?
            Rails.logger.info("Processing #{ready_episodes.length} ready episodes")
            finisher_block.call(ready_episodes) if finisher_block.present?
          end

          check_for_stuck_episodes(still_waiting_episodes)

          still_waiting_episodes
        end
      end
    end

    def prepare_for_delivery!(eps)
      Rails.logger.tagged("Apple::Publisher##{__method__}") do
        Apple::Episode.prepare_for_delivery(eps)
      end
    end

    def archive!(eps = episodes_to_archive)
      Rails.logger.tagged("Apple::Publisher##{__method__}") do
        eps.each_slice(PUBLISH_CHUNK_LEN) do |chunked_eps|
          res = Apple::Episode.archive(api, show, chunked_eps)
          Rails.logger.info("Archived #{res.length} episodes.")
        end
      end
    end

    def unarchive!(eps = episodes_to_unarchive)
      Rails.logger.tagged("Apple::Publisher##{__method__}") do
        eps.each_slice(PUBLISH_CHUNK_LEN) do |chunked_eps|
          res = Apple::Episode.unarchive(api, show, chunked_eps)
          Rails.logger.info("Un-Archived #{res.length} episodes.")
        end
      end
    end

    def raise_delivery_processing_errors(eps)
      pdfs_with_errors = eps.map(&:podcast_delivery_files).flatten.filter(&:processed_errors?)

      pdfs_with_errors.each do |pdf|
        Rails.logger.error("Podcast delivery file has processing errors",
          {episode_id: pdf.episode.id,
           podcast_delivery_file_id: pdf.id,
           asset_processing_state: pdf.asset_processing_state,
           asset_delivery_state: pdf.asset_delivery_state})
      end

      if pdfs_with_errors.any?
        raise Apple::PodcastDeliveryFile::DeliveryFileError.new(
          "Found processing errors on #{pdfs_with_errors.length} podcast delivery files"
        )
      end

      true
    end

    def wait_for_versioned_source_metadata(eps)
      Rails.logger.tagged("##{__method__}") do
        # wait for the audio version to be created
        (waiting_timed_out, _) =
          Apple::PodcastContainer.wait_for_versioned_source_metadata(api, eps)
        raise "Timed out waiting for audio version" if waiting_timed_out
      end
    end

    def wait_for_upload_processing(eps)
      Rails.logger.tagged("##{__method__}") do
        pdfs = eps.map(&:podcast_delivery_files).flatten

        (waiting_timed_out, _) = Apple::PodcastDeliveryFile.wait_for_delivery(api, pdfs)
        raise "Timed out waiting for delivery" if waiting_timed_out

        (waiting_timed_out, _) = Apple::PodcastDeliveryFile.wait_for_processing(api, pdfs)
        raise "Timed out waiting for processing" if waiting_timed_out

        # Get the latest state of the podcast containers
        # which should include synced files
        Apple::PodcastContainer.poll_podcast_container_state(api, eps)
      end
    end

    def increment_asset_wait!(eps)
      Rails.logger.tagged("##{__method__}") do
        eps = eps.filter { |e| e.feeder_episode.apple_status.uploaded? }
        eps.each { |ep| ep.apple_episode_delivery_status.increment_asset_wait }
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
        Apple::Episode.create_episodes(api, create_apple_episodes)
        Rails.logger.info("Created remote episodes", {count: create_apple_episodes.length})

        # NOTE: We don't attempt to update the remote state of published episodes.
        # Once apple has parsed the feed, it will not allow changing any attributes.
        #
        # It's assumed that the episodes are created solely by the PRX web UI (not
        # on Podcasts Connect).

        # However, if the episode is drafting state,
        # then we can try to update the episode attributes
        draft_apple_episodes = eps.select(&:drafting?)
        Apple::Episode.update_episodes(api, draft_apple_episodes)
        Rails.logger.info("Updated remote episodes", {count: draft_apple_episodes.length})

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
        # Apple RSS scraping means we don't need deliveries for freemium episode images
        # But we do need asset deliveries for apple-only (non-rss) images

        Rails.logger.info("Starting podcast container sync")

        poll_podcast_containers!(eps)

        # The podcast container is storing the metadata for the audio file
        # (size, url, etc).
        # The 'reset' in this case means fetching new CDN urls for the audio and
        # making sure that we will HEAD their file sizes for later upload.
        # Only reset if we need delivery.
        res = Apple::PodcastContainer.create_podcast_containers(api, eps)
        Rails.logger.info("Created remote and local state for podcast containers.", {count: res.length})
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

    def update_audio_container_reference!(eps)
      Rails.logger.tagged("##{__method__}") do
        # link the podcast container with the audio to the episode
        res = Apple::Episode.update_audio_container_reference(api, eps)

        Rails.logger.info("Updated remote container references for episodes.", {count: res.length})
      end
    end

    def mark_as_delivered!(eps)
      Rails.logger.tagged("##{__method__}") do
        eps.each do |ep|
          Rails.logger.info("Marking episode as no longer needing delivery", {episode_id: ep.feeder_episode.id})
          ep.feeder_episode.apple_mark_as_delivered!
        end
      end
    end

    def mark_as_uploaded!(eps)
      Rails.logger.tagged("##{__method__}") do
        eps.each do |ep|
          Rails.logger.info("Marking episode as no longer needing delivery", {episode_id: ep.feeder_episode.id})
          ep.feeder_episode.apple_mark_as_uploaded!
        end
      end
    end

    def publish_drafting!(eps)
      Rails.logger.tagged("##{__method__}") do
        eps = eps.select { |ep| ep.drafting? && ep.container_upload_complete? }

        res = Apple::Episode.publish(api, show, eps)
        eps.each { |ep| ep.apple_episode_delivery_status.reset_asset_wait }

        Rails.logger.info("Published #{res.length} drafting episodes.")
      end
    end

    def reset_asset_wait!(eps)
      Rails.logger.tagged("##{__method__}") do
        eps.each { |ep| ep.apple_episode_delivery_status.reset_asset_wait }
      end
    end

    # Not used in any of the polling or publish routines, but useful for
    # debugging.  This removes the audio container reference from the episode,
    # but leaves the podcast container intact.
    def remove_audio_container_reference(eps, apple_mark_for_reupload: true)
      Rails.logger.tagged("##{__method__}") do
        Apple::Episode.remove_audio_container_reference(api, show, eps, apple_mark_for_reupload: apple_mark_for_reupload)
      end
    end

    private

    def check_for_stuck_episodes(waiting)
      return if waiting.empty?

      Rails.logger.info("Waiting for asset state processing", {
        episode_count: waiting.length,
        episode_ids: waiting.map(&:feeder_id),
        audio_asset_states: waiting.map(&:audio_asset_state).uniq
      })

      # Check for stuck episodes (>1 hour)
      stuck = waiting.filter { |ep|
        duration = ep.feeder_episode.measure_asset_processing_duration
        duration && duration > STUCK_EPISODE_TIMEOUT
      }

      if stuck.any?
        stuck.each do |ep|
          Rails.logger.error("Episodes stuck for over 1 hour", {
            episode_id: ep.feeder_id,
            duration: ep.feeder_episode.measure_asset_processing_duration
          })
          ep.apple_mark_for_reupload!
        end
        raise Apple::AssetStateTimeoutError.new(stuck)
      end
    end

    def filter_episodes_awaiting_asset_state(eps)
      eps.filter { |e| e.podcast_delivery_files.any?(&:api_marked_as_uploaded?) }
    end

    def partition_episodes_by_readiness(waiting_eps)
      ready_acc = []
      waiting_acc = []

      waiting_eps.each_slice(PUBLISH_CHUNK_LEN) do |batch|
        ready, waiting = Apple::Episode.probe_asset_state(api, batch)
        ready_acc.concat(ready)
        waiting_acc.concat(waiting)
      end

      [ready_acc, waiting_acc]
    end
  end
end
