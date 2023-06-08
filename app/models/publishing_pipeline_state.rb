class PublishingPipelineState < ApplicationRecord
  # add a scope that returns the most recent publishing attempts for each podcast
  scope :latest_by_queue_item, -> {
                                 where(id: PublishingPipelineState
                                  .group(:podcast_id, :publishing_queue_item_id)
                                  .select("max(id) as id"))
                               }

  scope :latest_by_podcast, -> {
                              where(id: PublishingPipelineState
                               .group(:podcast_id)
                               .select("max(id) as id"))
                            }

  belongs_to :publishing_queue_item
  belongs_to :podcast

  enum status: {
    created: 0,
    started: 1,
    publishing_rss: 2,
    publishing_apple: 3,
    complete: 4,
    error: 5
  }

  TERMINAL_STATUSES = [statuses[:complete], statuses[:error]]

  # None of the methods in here are threadsafe if we assume that creating
  # published artifacts is non-idempotent (e.g. creating remote Apple resources)

  def self.attempt!(podcast, perform_later: true)
    podcast.with_publish_lock do
      next if PublishingQueueItem.unfinished_items(podcast).empty?
      next if PublishingQueueItem.unfinished_attempted_item(podcast).present?

      # Dedupe the work, grab the latest unfinished item in the queue
      latest_unfinished_item = PublishingQueueItem.unfinished_items(podcast).first

      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: latest_unfinished_item, status: :created)

      if perform_later
        PublishFeedJob.perform_later(podcast)
      else
        PublishFeedJob.perform_now(podcast)
      end
    end
  end

  def self.guard_for_terminal_state_transition(podcast)
    if PublishingQueueItem.settled_work?(podcast)
      Rails.logger.error("Podcast #{podcast.id} has no unfinished work, cannot complete", {podcast_id: podcast.id})
      true
    end
  end

  def self.complete!(podcast)
    podcast.with_publish_lock do
      next if guard_for_terminal_state_transition(podcast)

      pqi = PublishingQueueItem.unfinished_attempted_item(podcast)
      create!(podcast: podcast, publishing_queue_item: pqi, status: :complete)
    end
  end

  def self.error!(podcast)
    podcast.with_publish_lock do
      next if guard_for_terminal_state_transition(podcast)

      pqi = PublishingQueueItem.unfinished_attempted_item(podcast)
      create!(podcast: podcast, publishing_queue_item: pqi, status: :error)
    end
  end

  def self.started!(podcast)
    podcast.with_publish_lock do
      pqi = PublishingQueueItem.unfinished_attempted_item(podcast)
      create!(podcast: podcast, publishing_queue_item: pqi, status: :started)
    end
  end

  def self.settle_remaining!(podcast)
    attempt!(podcast)
  end

  def self.complete?(podcast)
    latest_attempt(podcast)&.complete?
  end

  def self.latest_attempt(podcast)
    where(podcast_id: podcast.id).latest_by_podcast.first
  end

  def complete_publishing!
    self.class.create!(podcast: podcast, publishing_queue_item: publishing_queue_item, status: :complete)
  end
end
