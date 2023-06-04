class PublishingQueueItem < ApplicationRecord
  scope :max_id_grouped, -> { group(:podcast_id).select("max(id) as id") }
  scope :latest_attempted, -> { joins(:publishing_attempts).order("publishing_attempts.id desc") }
  scope :latest_completed, -> { latest_attempted.where(publishing_attempts: {complete: true}) }

  # Has at most two publishing attempt logs: one when initiated and one when completed
  has_many :publishing_attempts
  has_one :latest_attempt, -> { order(id: :desc) }, class_name: "PublishingAttempt"
  belongs_to :podcast

  def self.settle_queue(podcast)
    # TODO handle expired / failed attempts in the case where the publishing
    # state has not been updated for some reason

    # Handle the base case where there are items in the queue that need to be scheduled
    # for publishing.
    # Take the latest item:

    PublishingQueueItem
  end

  def complete?
    latest_attempt&.complete?
  end

  def publish!
    if podcast.locked?
      Rails.logger.info "Podcast #{podcast.id} is locked, skipping publish", {podcast_id: podcast.id, publishing_queue_item_id: id}
      return false
    end

    PublishingAttempt.create!(podcast: podcast, publishing_queue_item: self)
    create_publish_job
  end

  def create_publish_job
    PublishFeedJob.perform_later(self)
  end
end
