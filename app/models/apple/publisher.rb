# frozen_string_literal: true

module Apple
  class Publisher
    attr_reader :public_feed,
                :private_feed,
                :api,
                :show

    def self.from_apple_credential(apple_credential)
      api = Apple::Api.from_apple_credentials(apple_credential)

      new(api: api,
          public_feed: apple_credential.public_feed,
          private_feed: apple_credential.private_feed)
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
      @episodes_to_sync ||= private_feed.
                            apple_filtered_episodes.map do |ep|
        Apple::Episode.new(show: show, feeder_episode: ep)
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

    def publish!
      show.sync!
      raise 'Missing Show!' unless show.apple_id.present?

      # only create if needed
      sync_episodes!
      sync_podcast_containers!
      sync_podcast_deliveries!
      sync_podcast_delivery_files!

      # upload and mark as uploaded
      execute_upload_operations!

      wait_for_upload_processing

      publish_drafting!

      # success
      SyncLog.create!(feeder_id: public_feed.id, feeder_type: :feeds, external_id: show.apple_id)
    rescue Apple::ApiError => e
      SyncLog.create!(feeder_id: public_feed.id, feeder_type: :feeds)
      raise e
    end

    def wait_for_upload_processing
      pdfs = episodes_to_sync.map(&:podcast_delivery_files).flatten

      res = Apple::PodcastDeliveryFile.wait_for_delivery_files(api, pdfs)
    end

    def sync_episodes!
      Rails.logger.info('Starting podcast episode sync')

      create_apple_episodes = episodes_to_sync.select(&:apple_new?)
      Rails.logger.info("Created remote / local state for #{create_apple_episodes.length} episodes.")

      update_apple_episodes = episodes_to_sync.select { |ep| ep.apple_persisted? && ep.apple_only? }
      Rails.logger.info("Updated remote / local state for #{update_apple_episodes.length} episodes.")

      Apple::Episode.create_episodes(api, create_apple_episodes)
      Apple::Episode.update_episodes(api, update_apple_episodes)
      show.reload
    end

    def sync_podcast_containers!
      # TODO: right now we only create one container,
      # Apple RSS scaping means we don't need containers for freemium episode images
      # But we do need asset containers for apple-only (non-rss) images

      Rails.logger.info('Starting podcast container sync')

      # Scan and update for existing containers
      res = Apple::PodcastContainer.update_podcast_container_state(api, episodes_to_sync)
      Rails.logger.info("Updated local state for #{res.length} podcast containers.")

      eps = Apple::PodcastContainer.create_podcast_containers(api, episodes_to_sync)
      res = Apple::Episode.update_audio_container_reference(api, eps)
      Rails.logger.info("Created remote / local state for #{eps.length} podcast containers.")
      Rails.logger.info("Updated remote container references for #{res.length} episodes.")

      res = Apple::PodcastContainer.update_podcast_container_file_metadata(api, episodes_to_sync)
      Rails.logger.info("Updated remote state for #{res.length} podcast containers.")
    end

    def sync_podcast_deliveries!
      Rails.logger.info('Starting podcast deliveries sync')

      res = Apple::PodcastDelivery.update_podcast_deliveries_state(api, episodes_to_sync)
      Rails.logger.info("Updated local state for #{res.length} podcast deliveries.")

      res = Apple::PodcastDelivery.create_podcast_deliveries(api, episodes_to_sync)
      Rails.logger.info("Created remote / local state for #{res.length} podcast deliveries.")
    end

    def sync_podcast_delivery_files!
      Rails.logger.info('Starting podcast delivery files sync')

      res = Apple::PodcastDeliveryFile.update_podcast_delivery_files_state(api, episodes_to_sync)
      Rails.logger.info("Updated local state for #{res.length} delivery files.")

      res = Apple::PodcastDeliveryFile.create_podcast_delivery_files(api, episodes_to_sync)
      Rails.logger.info("Created remote/local state for #{res.length} podcast delivery files.")
    end

    def execute_upload_operations!
      upload_operation_result = Apple::UploadOperation.execute_upload_operations(api, episodes_to_sync)
      delivery_file_ids = upload_operation_result.map { |r| r['request_metadata']['podcast_delivery_file_id'] }
      pdfs = ::Apple::PodcastDeliveryFile.where(id: delivery_file_ids)
      ::Apple::PodcastDeliveryFile.mark_uploaded(api, pdfs)
    end

    def publish_drafting!
      eps = episodes_to_sync.select { |ep| ep.drafting? && ep.apple_upload_complete? }

      res = Apple::Episode.publish(api, eps)
      Rails.logger.info("Published #{res.length} drafting episodes.")
    end
  end
end
