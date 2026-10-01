class PublishingPipelineState < ApplicationRecord
  TERMINAL_STATUSES = [:complete, :error, :expired, :retry].freeze
  FAILURE_STATUSES = [:error, :expired, :error_integration, :retry].freeze
  UNIQUE_STATUSES = TERMINAL_STATUSES + [:created, :started]

  # Raised when a worker's pipeline was expired or replaced; the worker must
  # stop without writing any more state. Not a StandardError, so ordinary
  # `rescue => e` handlers let it through and only explicit rescues catch it.
  class LostOwnershipError < Exception; end # standard:disable Lint/InheritException

  # How long a pipeline can go without a heartbeat before the reaper treats its
  # worker as dead. Running workers beat on every transition and wait-loop tick.
  HEARTBEAT_STALE_AFTER = 10.minutes.freeze

  scope :unfinished_pipelines, -> { where(publishing_queue_item_id: PublishingQueueItem.all_unfinished_items) }
  scope :running_pipelines, -> { unfinished_pipelines }

  # A pipeline with no heartbeat yet (job not started) ages from its created state
  scope :expired_pipelines, -> {
                              stale_items = unfinished_pipelines.created
                                .joins(:publishing_queue_item)
                                .where("COALESCE(publishing_queue_items.heartbeat_at, publishing_pipeline_states.created_at) < ?", HEARTBEAT_STALE_AFTER.ago)
                                .select(:publishing_queue_item_id)

                              where(publishing_queue_item_id: stale_items)
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
    :published_integration,
    :complete,
    :error,
    :expired,
    :error_integration,
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

  def self.start!(podcast, pub_item)
    state_transition(podcast, :started, pub_item)
  end

  def self.publish_rss!(podcast, pub_item)
    state_transition(podcast, :published_rss, pub_item)
  end

  def self.error_rss!(podcast, pub_item)
    state_transition(podcast, :error_rss, pub_item)
  end

  # TODO: do something with the integration type?
  def self.publish_integration!(podcast, pub_item)
    state_transition(podcast, :published_integration, pub_item)
  end

  def self.error_integration!(podcast, pub_item)
    state_transition(podcast, :error_integration, pub_item)
  end

  def self.complete!(podcast, pub_item)
    state_transition(podcast, :complete, pub_item)
  end

  def self.error!(podcast, pub_item)
    state_transition(podcast, :error, pub_item)
  end

  # The reaper expires whatever is currently running, with no owner check
  def self.expire!(podcast)
    podcast.with_publish_lock do
      pqi = PublishingQueueItem.current_unfinished_item(podcast)
      if pqi.present?
        create_state!(podcast, :expired, pqi)
      else
        Rails.logger.error("Podcast #{podcast.id} has no unfinished work, cannot transition state", {podcast_id: podcast.id, to_state: :expired})
        nil
      end
    end
  end

  def self.retry!(podcast, pub_item)
    state_transition(podcast, :retry, pub_item)
  end

  def self.expire_pipelines!
    Podcast.with_deleted.where(id: expired_pipelines.select(:podcast_id)).each do |podcast|
      Rails.logger.tagged("PublishingPipeLineState.expire_pipelines!", "Podcast:#{podcast.id}") do
        expire_if_stale!(podcast)
      end
    end
  end

  # Recheck under the lock: the worker may have beat, or the pipeline been
  # replaced, since the reaper selected it
  def self.expire_if_stale!(podcast)
    podcast.with_publish_lock do
      expire!(podcast) if expired?(podcast)
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

  # The database decides who owns the pipeline: pub_item is only the worker's
  # identity, and it must still be the podcast's current unfinished item
  def self.assert_owner!(podcast, pub_item)
    podcast.with_publish_lock do
      curr_running_item = PublishingQueueItem.current_unfinished_item(podcast)
      if pub_item.nil? || curr_running_item != pub_item
        Rails.logger.warn("Publishing worker lost ownership of podcast #{podcast.id} pipeline", {podcast_id: podcast.id, publishing_queue_item_id: pub_item&.id, running_queue_item: curr_running_item&.id})
        raise LostOwnershipError, "PublishingQueueItem #{pub_item&.id} is not the running item #{curr_running_item&.id} for podcast #{podcast.id}"
      end
    end
  end

  def self.state_transition(podcast, to_state, pub_item)
    podcast.with_publish_lock do
      assert_owner!(podcast, pub_item)
      create_state!(podcast, to_state, pub_item).tap { stamp_heartbeat!(pub_item) }
    end
  end

  # Worker liveness: stamped on the queue item, so pipeline states stay append-only
  def self.heartbeat!(podcast, pub_item)
    podcast.with_publish_lock do
      assert_owner!(podcast, pub_item)
      stamp_heartbeat!(pub_item)
    end
  end

  def self.stamp_heartbeat!(pqi)
    pqi.update_column(:heartbeat_at, Time.now)
  end

  def self.create_state!(podcast, to_state, pqi)
    Rails.logger.info("Transitioning podcast #{podcast.id} publishing pipeline to state #{to_state}", {podcast_id: podcast.id, to_state: to_state, running_queue_item: pqi.id})
    PublishingPipelineState.create!(podcast: podcast, publishing_queue_item: pqi, status: to_state)
  end

  def complete_publishing!
    self.class.complete!(podcast, publishing_queue_item)
  end

  def done?
    self.class.where(publishing_queue_item: publishing_queue_item).where(status: self.class.terminal_status_codes).exists?
  end

  private_class_method :state_transition, :create_state!, :stamp_heartbeat!
end
