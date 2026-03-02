# frozen_string_literal: true

module Apple
  class MediaInfo
    include Apple::ApiResponse
    include Apple::ApiWaiting

    attr_accessor :episode, :source_media_version_id, :source_size, :source_url

    def initialize(episode:, source_media_version_id: nil, source_size: nil, source_url: nil)
      @episode = episode
      @source_media_version_id = source_media_version_id
      @source_size = source_size
      @source_url = source_url
    end

    def has_media_version?
      source_media_version_id.present? &&
        source_media_version_id == episode.feeder_episode.media_version_id
    end

    def source_attributes
      {source_media_version_id: source_media_version_id, source_size: source_size, source_url: source_url}
    end

    def self.probe_source_file_metadata(api, episodes)
      episodes = episodes.select { |ep| ep.podcast_container.present? }

      containers = episodes.map(&:podcast_container)
      episodes_by_container_id = episodes.map { |ep| [ep.podcast_container.id, ep] }.to_h

      results = api.bridge_remote_and_retry!("headFileSizes", containers.map(&:head_file_size_bridge_params))

      join_on("podcast_container_id", containers, results).map do |container, row|
        content_length = row.dig("api_response", "val", "data", "headers", "content-length")
        cdn_url = row.dig("api_response", "val", "data", "redirect_chain_end_url")
        media_version = row.dig("api_response", "val", "data", "episode_media_version")

        raise "Missing content-length in response" if content_length.blank?
        raise "Missing cdn_url in response" if cdn_url.blank?
        raise "Missing media_version in response" if media_version.blank?

        episode = episodes_by_container_id.fetch(container.id)

        new(
          episode: episode,
          source_media_version_id: media_version.to_i,
          source_size: content_length.to_i,
          source_url: cdn_url
        )
      end
    end

    def self.wait_for_versioned_source_metadata(api, episodes, wait_interval: 10.seconds, wait_timeout: 1.minute)
      raise "Missing podcast container for episode" if episodes.map(&:podcast_container).any?(&:nil?)

      all_media_infos = []

      (timed_out, _remaining) = wait_for(episodes, wait_interval: wait_interval, wait_timeout: wait_timeout) do |remaining_episodes|
        containers = Apple::PodcastContainer.reset_source_file_metadata(remaining_episodes)
        Rails.logger.info("Reset container source metadata", {reset_count: containers.length})

        media_infos = probe_source_file_metadata(api, remaining_episodes)
        Rails.logger.info("Updated container source metadata.", {count: media_infos.length})

        ready, not_ready = media_infos.partition(&:has_media_version?)
        all_media_infos.concat(ready)

        not_ready.map(&:episode)
      end

      [timed_out, all_media_infos]
    end
  end
end
