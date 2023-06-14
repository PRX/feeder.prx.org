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

  def self.unfinished_pipelines
    where(publishing_queue_item_id: PublishingQueueItem.all_unfinished_items)
  end

  def self.start_pipeline!(podcast)
    PublishingQueueItem.ensure_queued!(podcast)
    attempt!(podcast)
  end

  # None of the methods that grab locks are threadsafe if we assume that
  # creating published artifacts is non-idempotent (e.g. creating remote Apple
  # resources)
  def self.attempt!(podcast, perform_later: true)
    podcast.with_publish_lock do
      next if PublishingQueueItem.unfinished_items(podcast).empty?
      next if PublishingQueueItem.unfinished_attempted_item(podcast).present?

      # Dedupe the work, grab the latest unfinished item in the queue
      latest_unfinished_item = PublishingQueueItem.unfinished_items(podcast).first

      PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: latest_unfinished_item, status: :created)

      if perform_later
        Rails.logger.info("Scheduling PublishFeedJob for podcast #{podcast.id}", {podcast_id: podcast.id})
        PublishFeedJob.perform_later(podcast)
      else
        Rails.logger.info("Performing PublishFeedJob for podcast #{podcast.id}", {podcast_id: podcast.id})
        PublishFeedJob.perform_now(podcast)
      end
    end
  end

  def self.complete!(podcast)
    state_transition(podcast, :complete)
  end

  def self.error!(podcast)
    state_transition(podcast, :error)
  end

  def self.started!(podcast)
    state_transition(podcast, :started)
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

  def self.state_transition(podcast, to_state)
    pqi = PublishingQueueItem.unfinished_attempted_item(podcast)
    if pqi.present?
      PublishingPipelineState.create(podcast: podcast, publishing_queue_item: pqi, status: to_state)
    else
      Rails.logger.error("Podcast #{podcast.id} has no unfinished work, cannot complete", {podcast_id: podcast.id})
      nil
    end
  end

  private_class_method :state_transition
end
