module Apple
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, -> { with_deleted }, class_name: "::Episode"

    def self.update_status(episode, attrs)
      new_status = (episode.apple_episode_delivery_status&.dup || default_status(episode))
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

    def mark_as_delivered!
      self.class.update_status(episode, delivered: true)
    end

    def mark_as_not_delivered!
      self.class.update_status(episode, delivered: false)
    end
  end
end
