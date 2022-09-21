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
    end

    def publish!
      show.sync!
      raise "Missing Show!" unless show.id.present?

      sync_episodes!

      show.reload

      # only create if needed
      create_podcast_containers!
      create_podcast_deliveries!
      create_podcast_delivery_files!

      # success
      SyncLog.create!(feeder_id: feed.id, feeder_type: :feeds, external_id: show.id)
    rescue Apple::ApiError => _e
      SyncLog.create!(feeder_id: feed.id, feeder_type: :feeds)
    end

    def get_podcast_containers
      Apple::PodcastContainer.get_podcast_containers(api, episodes_to_sync)
    end

    def create_podcast_containers!
      # TODO: right now we only create one container,
      # Apple RSS scaping means we don't need containers for freemium episode images
      # But we do need asset containers for apple-only (non-rss) images
      Apple::PodcastContainer.create_podcast_containers(api, episodes_to_sync, show)
      Apple::PodcastContainer.update_podcast_container_file_metadata(api, episodes_to_sync)
    end

    def get_podcast_deliveries
      # TODO: right now we only create one container,
      Apple::PodcastDelivery.get_podcast_deliveries(api, episodes_to_sync)
    end

    def create_podcast_deliveries!
      Apple::PodcastDelivery.create_podcast_deliveries(api, episodes_to_sync)
    end

    def create_podcast_delivery_files!
      Apple::PodcastDeliveryFile.create_podcast_delivery_files(api, episodes_to_sync)
    end
  end
end
