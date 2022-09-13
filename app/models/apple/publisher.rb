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

      # success
      SyncLog.create!(feeder_id: feed.id, feeder_type: "f", external_id: show.id)
    rescue Apple::ApiError => _e
      SyncLog.create!(feeder_id: feed.id, feeder_type: "f")
    end

    def get_podcast_containers
      Apple::PodcastContainer.get_podcast_containers(api, episodes_to_sync)
    end

    def create_podcast_containers!
      Apple::PodcastContainer.create_podcast_containers(api, episodes_to_sync, show)
    end

    def get_podcast_deliveries
      Apple::PodcastDelivery.get_podcast_deliveries(api, episodes_to_sync)
    end

    def create_podcast_deliveries!
      Apple::PodcastDelivery.create_podcast_deliveries(api, episodes_to_sync)
    end
  end
end
