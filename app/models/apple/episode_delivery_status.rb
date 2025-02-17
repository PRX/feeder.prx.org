module Apple
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    def self.measure_asset_processing_duration(apple_episode_delivery_statuses)
      statuses = apple_episode_delivery_statuses.to_a

      last_status = statuses.shift
      return nil unless last_status&.asset_processing_attempts.to_i.positive?

      start_status = statuses.find { |status| status.asset_processing_attempts.to_i.zero? }
      return nil unless start_status

      Time.now - start_status.created_at
    end

    def self.update_status(episode, attrs)
      new_status = episode.apple_episode_delivery_status&.dup || default_status(episode)
      new_status.assign_attributes(attrs)
      new_status.save!
      episode.apple_episode_delivery_statuses.reset
      new_status
    end

    def self.default_status(episode)
      new(episode: episode)
    end

    def increment_asset_wait
      self.class.update_status(episode, asset_processing_attempts: (asset_processing_attempts || 0) + 1)
    end

    def reset_asset_wait
      self.class.update_status(episode, asset_processing_attempts: 0)
    end
  end
end
