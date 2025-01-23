class PublishingPipelineState < ApplicationRecord
  TERMINAL_STATUSES = [:complete, :error, :expired, :retry].freeze
  FAILURE_STATUSES = [:error, :expired, :error_apple, :retry].freeze
  UNIQUE_STATUSES = TERMINAL_STATUSES + [:created, :started]

  # Handle the max timout for a publishing pipeline: Pub RSS job + Pub Apple job + a few extra minutes of flight
  TIMEOUT = 30.minutes.freeze

  scope :unfinished_pipelines, -> { where(publishing_queue_item_id: PublishingQueueItem.all_unfinished_items) }
  scope :running_pipelines, -> { unfinished_pipelines }

  scope :expired_pipelines, -> {
                              pq_items = PublishingQueueItem
                                .where(id: unfinished_pipelines.where("publishing_pipeline_states.created_at < ?", TIMEOUT.ago)
                              .select(:publishing_queue_item_id))

                              where(publishing_queue_item: pq_items)
                            }
  scope :latest_failed_pipelines, -> {
                                    # Grab the latest attempted Publishing Item AND the latest failed Pub Item.
                                    # If that is a non-null intersection, then we have a current/latest+failed pipeline.
                                    where(publishing_queue_item_id: PublishingQueueItem.latest_attempted.latest_failed.select(:id))
                                  }

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
  scope :latest_pipelines, -> {
                             where(
                               publishing_queue_item_id: latest_by_podcast.select(:publishing_queue_item_id)
                             )
                           }

  scope :latest_pipeline, ->(podcast) { latest_pipelines.where(podcast: podcast) }

  belongs_to :publishing_queue_item
  belongs_to :podcast, -> { with_deleted }

  enum :status, [
    :created,
    :started,
    :published_rss,
    :published_apple,
    :complete,
    :error,
    :expired,
    :error_apple,
    :error_rss,
    :retry
  ]

  validate :podcast_ids_match
  validate :no_transition_from_terminal_state, on: :create
  validate :no_update, on: :update

  after_save :log_state_on_queue_item

  def log_state_on_queue_item
    publishing_queue_item.update!(last_pipeline_state: status)
  end

  def no_update
    errors.add(:base, "cannot update!")
  end

  def podcast_ids_match
    if podcast_id != publishing_queue_item&.podcast_id
      errors.add(:podcast_id, "must match the podcast_id of the publishing_queue_item")
    end
  end

  def no_transition_from_terminal_state
    if done?
      errors.add(:status, "cannot transition from a terminal state")
    end
  end

  def self.terminal_status_codes
    TERMINAL_STATUSES.map { |s| statuses[s] }
  end

  def self.unique_status_codes
    UNIQUE_STATUSES.map { |s| statuses[s] }
  end

  def self.most_recent_state(podcast)
    latest_by_podcast.where(podcast_id: podcast.id).first
  end

  def self.start_pipeline!(podcast)
    Rails.logger.tagged("PublishingPipeLineState.start_pipeline!", "Podcast:#{podcast.id}") do
      PublishingQueueItem.ensure_queued!(podcast)
      attempt!(podcast)
    end
  end

  # None of the methods that grab locks are threadsafe if we assume that
  # creating published artifacts is non-idempotent (e.g. creating remote Apple
  # resources)
  def self.attempt!(podcast, perform_later: true)
    Rails.logger.tagged("PublishingPipeLineState.attempt!") do
      podcast.with_publish_lock do
        if PublishingQueueItem.unfinished_items(podcast).empty?
          Rails.logger.info("Unfinished items empty, nothing to do", podcast_id: podcast.id)
          next
        end
        if (curr_running_item = PublishingQueueItem.current_unfinished_item(podcast))
          Rails.logger.info("Podcast's PublishingQueueItem already has running pipeline", podcast_id: podcast.id, running_queue_item: curr_running_item.id)
          next
        end

        # Dedupe the work, grab the latest unfinished item in the queue
        latest_unfinished_item = PublishingQueueItem.unfinished_items(podcast).first

        Rails.logger.info("Creating publishing pipeline for podcast #{podcast.id}", {podcast_id: podcast.id, queue_item_id: latest_unfinished_item.id})
        PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: latest_unfinished_item, status: :created)

        Rails.logger.info("Initiating PublishFeedJob for podcast #{podcast.id}", {podcast_id: podcast.id, queue_item_id: latest_unfinished_item.id, perform_later: perform_later})
        if perform_later
          PublishFeedJob.perform_later(podcast, latest_unfinished_item)
        else
          PublishFeedJob.perform_now(podcast, latest_unfinished_item)
        end

        latest_unfinished_item
      end
    end
  end

  def self.expired?(podcast)
    expired_pipelines.where(podcast: podcast).exists?
  end

  def self.start!(podcast)
    state_transition(podcast, :started)
  end

  def self.publish_rss!(podcast)
    state_transition(podcast, :published_rss)
  end

  def self.publish_apple!(podcast)
    state_transition(podcast, :published_apple)
  end

  def self.error_apple!(podcast)
    state_transition(podcast, :error_apple)
  end

  def self.error_rss!(podcast)
    state_transition(podcast, :error_rss)
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

  def self.retry!(podcast)
    state_transition(podcast, :retry)
  end

  def self.expire_pipelines!
    Podcast.with_deleted.where(id: expired_pipelines.select(:podcast_id)).each do |podcast|
      Rails.logger.tagged("PublishingPipeLineState.expire_pipelines!", "Podcast:#{podcast.id}") do
        expire!(podcast)
      end
    end
  end

  def self.latest_failed_publishing_queue_items
    PublishingQueueItem.where(id: latest_failed_pipelines.select(:publishing_queue_item_id).distinct)
  end

  def self.latest_failed_podcasts
    Podcast.where(id: latest_failed_publishing_queue_items.select(:podcast_id).distinct)
  end

  def self.retry_failed_pipelines!
    latest_failed_podcasts.each do |podcast|
      Rails.logger.tagged("PublishingPipeLineState.retry_failed_pipelines!", "Podcast:#{podcast.id}") do
        start_pipeline!(podcast)
      end
    end
  end

  def self.settle_remaining!(podcast)
    Rails.logger.tagged("PublishingPipeLineState.settle_remaining!") do
      attempt!(podcast)
    end
  end

  def self.complete?(podcast)
    most_recent_state(podcast)&.complete?
  end

  def self.state_transition(podcast, to_state)
    podcast.with_publish_lock do
      pqi = PublishingQueueItem.current_unfinished_item(podcast)
      curr_running_item = PublishingQueueItem.current_unfinished_item(podcast)
      if pqi.present?
        Rails.logger.info("Transitioning podcast #{podcast.id} publishing pipeline to state #{to_state}", {podcast_id: podcast.id, to_state: to_state, running_queue_item: curr_running_item&.id})
        PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: to_state)
      else
        Rails.logger.error("Podcast #{podcast.id} has no unfinished work, cannot transition state", {podcast_id: podcast.id, to_state: to_state})
        nil
      end
    end
  end

  def complete_publishing!
    self.class.complete!(podcast)
  end

  def done?
    self.class.where(publishing_queue_item: publishing_queue_item).where(status: self.class.terminal_status_codes).exists?
  end

  private_class_method :state_transition
end
