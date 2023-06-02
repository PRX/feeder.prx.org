class PublishingAttempt < ApplicationRecord
  # add a scope that returns the most recent publishing attempt for a given podcast
  scope :latest, -> { order(created_at: :desc) }

  belongs_to :publishing_log
  belongs_to :podcast

  def self.latest_attempt(podcast)
    PublishingAttempt.where(podcast_id: podcast.id).latest.first
  end

  def mark_complete
    update!(complete: true)
  end

  def schedule!
    PublishingAttempt.create!(podcast: podcast, publishing_log: PublishingLog.create!(podcast: podcast))
  end
end
