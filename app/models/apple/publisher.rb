# frozen_string_literal: true

module Apple
  class Publisher
    attr_reader :feed,
                :api,
                :show

    def initialize(feed)
      @feed = feed
      @api = Apple::Api.from_env
      @show = Apple::Show.new(@feed)
    end

    def podcast
      feed.podcast
    end

    def episodes_to_sync
      @episodes ||= feed.
                    apple_filtered_episodes.map do |ep|
        Apple::Episode.new(show, ep)
      end
    end

    def episode_ids
      @episode_ids ||= episodes_to_sync.map(&:id).sort
    end

    def find_episode(id)
      @find_episode ||=
        episodes_to_sync.map { |e| [e.id, e] }.to_h

      @find_episode.fetch(id)
    end

    def sync_episodes!
      create_apple_episodes = episodes_to_sync.select(&:apple_new?)
      update_apple_episodes = episodes_to_sync.select { |ep| ep.apple_persisted? && ep.apple_only? }

      Apple::Episode.create_episodes(api, create_apple_episodes)
      Apple::Episode.update_episodes(api, update_apple_episodes)
      show.reload
    end

    def publish!
      show.sync!
      raise "Missing Show!" unless show.apple_id.present?

      sync_episodes!

      # only create if needed
      sync_podcast_containers!
      sync_podcast_deliveries!
      sync_podcast_delivery_files!

      # upload and mark as uploaded
      execute_upload_operations!

      wait_for_upload_processing

      # wait for media to process
      # link up data models
      # update episodes as published

      # success
      SyncLog.create!(feeder_id: feed.id, feeder_type: :feeds, external_id: show.apple_id)
    rescue Apple::ApiError => _e
      SyncLog.create!(feeder_id: feed.id, feeder_type: :feeds)
      raise e
    end

    def wait_for_upload_processing
      pdfs = episodes_to_sync.map(&:feeder_episode).map(&:apple_delivery_files).flatten

      res = Apple::PodcastDeliveryFile.wait_for_delivery_files(api, pdfs)
    end

    def get_podcast_containers
      Apple::PodcastContainer.get_podcast_containers(api, episodes_to_sync)
    end

    def sync_podcast_containers!
      # TODO: right now we only create one container,
      # Apple RSS scaping means we don't need containers for freemium episode images
      # But we do need asset containers for apple-only (non-rss) images

      Rails.logger.info("Starting podcast container sync")

      res = Apple::PodcastContainer.update_podcast_container_state(api, episodes_to_sync)
      Rails.logger.info("Updated local state for #{res.length} podcast containers.")

      res = Apple::PodcastContainer.create_podcast_containers(api, episodes_to_sync)
      Rails.logger.info("Created remote / local state for #{res.length} podcast containers.")

      res = Apple::PodcastContainer.update_podcast_container_file_metadata(api, episodes_to_sync)
      Rails.logger.info("Updated remote state for #{res.length} podcast containers.")
    end

    def get_podcast_deliveries
      # TODO: right now we only create one container,
      Apple::PodcastDelivery.get_podcast_deliveries(api, episodes_to_sync)
    end

    def sync_podcast_deliveries!
      Apple::PodcastDelivery.sync_podcast_deliveries(api, episodes_to_sync)
    end

    def sync_podcast_delivery_files!
      Apple::PodcastDeliveryFile.sync_podcast_delivery_files(api, episodes_to_sync)
    end

    def execute_upload_operations!
      upload_operation_result = Apple::UploadOperation.execute_upload_operations(api, episodes_to_sync)
      delivery_file_ids = upload_operation_result.map { |r| r["request_metadata"]["podcast_delivery_file_id"] }
      pdfs = ::Apple::PodcastDeliveryFile.where(id: delivery_file_ids)
      ::Apple::PodcastDeliveryFile.mark_uploaded(api, pdfs)
    end
  end
end
