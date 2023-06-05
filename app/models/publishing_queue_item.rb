class PublishingQueueItem < ApplicationRecord
  scope :max_id_grouped, -> { group(:podcast_id).select("max(id) as id") }
  scope :latest_attempted, -> { joins(:publishing_attempts).order("publishing_attempts.id desc") }
  scope :latest_completed, -> { latest_attempted.where(publishing_attempts: {complete: true}) }

  # Has at most two publishing attempt logs: one when initiated and one when completed
  has_many :publishing_attempts
  has_one :latest_attempt, -> { order(id: :desc) }, class_name: "PublishingAttempt"
  belongs_to :podcast

  def self.settled_work?(podcast)
    # test that there is no publishing attempt in progress
    unfinished_attempted_item(podcast).nil?
  end

  def self.unfinished_attempted_item(podcast)
    # test that there is no publishing attempt in progress
    joins(:publishing_attempts)
      .where(id: unfinished_items(podcast))
      .where(publishing_attempts: {complete: false}).first
  end

  def self.unfinished_items(podcast)
    frag = <<~SQL
      id > COALESCE((SELECT max(publishing_queue_item_id)
                     FROM publishing_attempts WHERE podcast_id = :podcast_id AND complete = true), -1)
    SQL

    where(podcast: podcast)
      .where(frag, podcast_id: podcast.id)
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
