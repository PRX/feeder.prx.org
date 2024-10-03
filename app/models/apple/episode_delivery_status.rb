module Apple
  class EpisodeDeliveryStatus < ApplicationRecord
    belongs_to :episode, class_name: "::Episode"

    def self.update_status(episode, attrs)
      new_status = (episode.apple_episode_delivery_status&.dup || new(episode: episode))
      new_status.assign_attributes(attrs)
      new_status.save!
      episode.apple_episode_delivery_statuses.reset
      new_status
    end
  end
end
