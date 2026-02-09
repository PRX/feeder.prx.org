class EpisodesFeed < ApplicationRecord
  self.primary_key = :episode_id, :feed_id

  belongs_to :episode, touch: true
  belongs_to :feed
end
