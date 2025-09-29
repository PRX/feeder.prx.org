module Apple
  class AssetStateTimeoutError < RuntimeError
    attr_reader :episodes, :attempts, :asset_wait_duration

    def initialize(episodes)
      @episodes = episodes
      @attempts = episodes.map { |ep| ep.apple_episode_delivery_status.asset_processing_attempts }.max
      @asset_wait_duration = episodes.map { |ep| ep.feeder_episode.measure_asset_processing_duration }.compact.max
      super("Timeout waiting for asset state change: Episodes: #{episode_ids}, Attempts: #{attempts}, Asset Wait Duration: #{asset_wait_duration}")
    end

    def episode_ids
      episodes.map(&:feeder_id)
    end

    def raise_publishing_error?
      %i[error fatal].include?(log_level)
    end

    def log_level
      case attempts
      when 0..4
        :warn
      when 5
        :error
      else
        :fatal
      end
    end
  end
end
