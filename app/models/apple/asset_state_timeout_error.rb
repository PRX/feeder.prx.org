module Apple
  class AssetStateTimeoutError < RuntimeError
    attr_reader :episodes, :attempts

    def initialize(episodes)
      @episodes = episodes
      @attempts = episodes.map { |ep| ep.apple_episode_delivery_status.asset_processing_attempts }.max
      super("Timeout waiting for asset state change: Episodes: #{episode_ids}  Attempts: #{attempts}")
    end

    def episode_ids
      episodes.map(&:feeder_id)
    end
  end
end
