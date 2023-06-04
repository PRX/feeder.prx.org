class PublishingAttempt < ApplicationRecord
  # add a scope that returns the most recent publishing attempts for each podcast
  scope :latest_by_queue_item, -> {
                                 where(id: PublishingAttempt
                                  .group(:podcast_id, :publishing_queue_item_id)
                                  .select("max(id) as id"))
                               }

  scope :latest_by_podcast, -> {
                              where(id: PublishingAttempt
                               .group(:podcast_id)
                               .select("max(id) as id"))
                            }

  belongs_to :publishing_queue_item
  belongs_to :podcast

  # None of the methods in here are threadsafe if we assume that creating
  # published artifacts is non-idempotent (e.g. creating remote Apple resources)

  def self.complete?(podcast)
    latest_attempt(podcast)&.complete?
  end

  def self.latest_attempt(podcast)
    where(podcast_id: podcast.id).latest_by_podcast.first
  end

  def complete_publishing!
    self.class.create!(podcast: podcast, publishing_queue_item: publishing_queue_item, complete: true)
  end
end
