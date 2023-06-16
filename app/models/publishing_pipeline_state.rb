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

  enum status: [
    :created,
    :started,
    :published_rss,
    :published_apple,
    :complete,
    :error,
    :expired
  ]

  TERMINAL_STATUSES = [:complete, :error, :expired].freeze
  # Handle the max timout for a publishing pipeline: Pub RSS job + Pub Apple job + a few extra minutes of flight
  TIMEOUT = 30.minutes.freeze

  validate :podcast_ids_match

  def podcast_ids_match
    if podcast_id != publishing_queue_item&.podcast_id
      errors.add(:podcast_id, "must match the podcast_id of the publishing_queue_item")
    end
  end

  def self.terminal_status_codes
    TERMINAL_STATUSES.map { |s| statuses[s] }
  end

  def self.expired_pipelines
    pq_items = PublishingQueueItem
      .where(id: unfinished_pipelines.where("publishing_pipeline_states.created_at < ?", TIMEOUT.ago)
    .select(:publishing_queue_item_id))

    where(publishing_queue_item: pq_items)
  end

  def self.unfinished_pipelines
    where(publishing_queue_item_id: PublishingQueueItem.all_unfinished_items)
  end

  def self.running_pipelines
    unfinished_pipelines
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
      next if PublishingQueueItem.current_unfinished_item(podcast).present?

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

  def self.expired?(podcast)
    expired_pipelines.where(podcast: podcast).exists?
  end

  def self.start!(podcast)
    state_transition(podcast, :started)
  end

  def self.complete!(podcast)
    state_transition(podcast, :complete)
  end

  def self.error!(podcast)
    state_transition(podcast, :error)
  end

  def self.expire!(podcast)
    state_transition(podcast, :expired)
  end

  def self.expire_pipelines!
    Podcast.where(id: expired_pipelines.select(:podcast_id)).each do |podcast|
      Rails.logger.error("Cleaning up expired publishing pipeline for podcast #{podcast.id}", {podcast_id: podcast.id})
      expire!(podcast)
    end
  end

  def self.settle_remaining!(podcast)
    attempt!(podcast)
  end

  def self.complete?(podcast)
    most_recent_state(podcast)&.complete?
  end

  def self.most_recent_state(podcast)
    where(podcast_id: podcast.id).latest_by_podcast.first
  end

  def self.latest_pipeline(podcast)
    where(publishing_queue_item_id: where(podcast_id: podcast.id).latest_by_podcast.select(:publishing_queue_item_id))
  end

  def complete_publishing!
    self.class.create!(podcast: podcast, publishing_queue_item: publishing_queue_item, status: :complete)
  end

  def self.state_transition(podcast, to_state)
    podcast.with_publish_lock do
      pqi = PublishingQueueItem.current_unfinished_item(podcast)
      if pqi.present?
        PublishingPipelineState.create(podcast: podcast, publishing_queue_item: pqi, status: to_state)
      else
        Rails.logger.error("Podcast #{podcast.id} has no unfinished work, cannot transition state", {podcast_id: podcast.id, to_state: to_state})
        nil
      end
    end
  end

  private_class_method :state_transition
end
