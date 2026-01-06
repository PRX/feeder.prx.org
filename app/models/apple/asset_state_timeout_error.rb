module Apple
  class AssetStateTimeoutError < RuntimeError
    attr_reader :episodes, :asset_wait_duration

    # Duration thresholds in seconds
    WARN_THRESHOLD = 30.minutes.to_i
    ERROR_THRESHOLD = 60.minutes.to_i

    def initialize(episodes)
      @episodes = episodes
      @asset_wait_duration = episodes.map { |ep| ep.feeder_episode.measure_asset_processing_duration }.compact.max
      super("Timeout: Episodes: #{episode_ids}, Asset Wait Duration: #{asset_wait_duration}")
    end

    def episode_ids
      episodes.map(&:feeder_id)
    end

    def podcast_id
      episodes.first&.podcast_id
    end

    def log_error!
      Rails.logger.send(
        log_level,
        message,
        {
          podcast_id: podcast_id,
          asset_wait_duration: asset_wait_duration
        }
      )
    end

    def log_level
      duration = asset_wait_duration || 0
      if duration >= ERROR_THRESHOLD
        :error
      elsif duration >= WARN_THRESHOLD
        :warn
      else
        :info
      end
    end
  end
end
