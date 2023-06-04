class PublishingAttempt < ApplicationRecord
  # add a scope that returns the most recent publishing attempt for a given podcast
  scope :latest, -> { order(created_at: :desc) }

  belongs_to :publishing_queue_entry
  belongs_to :podcast

  # None of the methods in here are threadsafe if we assume that creating
  # published artifacts is non-idempotent (e.g. creatig remote Apple resources)

  def self.complete?(podcast)
    latest_attempt(podcast)&.complete?
  end

  def self.latest_attempt(podcast)
    where(podcast_id: podcast.id).latest.first
  end

  def complete_publishing!
    create!(podcast: podcast, publishing_log: publishing_log, complete: true)
  end
end
