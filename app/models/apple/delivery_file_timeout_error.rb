module Apple
  class DeliveryFileTimeoutError < RuntimeError
    attr_reader :episodes, :asset_wait_duration, :timeout_stage

    STAGE_DELIVERY = :delivery
    STAGE_PROCESSING = :processing
    STAGE_STUCK = :stuck

    # Duration thresholds in seconds
    WARN_THRESHOLD = 30.minutes.to_i
    ERROR_THRESHOLD = 60.minutes.to_i

    def initialize(episodes, stage:)
      @episodes = episodes
      @timeout_stage = stage
      @asset_wait_duration = episodes.map { |ep| ep.feeder_episode.measure_asset_processing_duration }.compact.max
      super("Timeout waiting for #{stage}: Episodes: #{episode_ids}, Asset Wait Duration: #{asset_wait_duration}")
    end

    def episode_ids
      episodes.map(&:feeder_id)
    end

    def raise_publishing_error?
      log_level == :error
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
          asset_wait_duration: asset_wait_duration,
          timeout_stage: timeout_stage
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
