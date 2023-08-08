class PublishingQueueItem < ApplicationRecord
  scope :max_id_grouped, -> { group(:podcast_id).select("max(id) as id") }

  scope :latest_attempted, -> {
                             where(id: PublishingPipelineState.group(:podcast_id).select("max(publishing_queue_item_id)"))
                               .order(id: :desc)
                           }
  scope :latest_complete, -> {
                            latest_by_status(PublishingPipelineState::TERMINAL_STATUSES)
                          }
  scope :latest_failed, -> {
                          latest_by_status(PublishingPipelineState::TERMINAL_FAILURE_STATUSES)
                        }

  scope :latest_by_status, ->(status) {
                             where(id: PublishingPipelineState.group(:podcast_id)
                             .where(status: status)
                             .select("max(publishing_queue_item_id)")).order(id: :desc)
                           }

  has_many :publishing_pipeline_states
  has_many :latest_state, -> { latest_by_queue_item }, class_name: "PublishingPipelineState"

  has_one :most_recent_state, -> { order(id: :desc) }, class_name: "PublishingPipelineState"
  belongs_to :podcast, -> { with_deleted }

  enum last_pipeline_state: PublishingPipelineState.statuses

  # in the style of the delivery logs in the exchange
  def self.delivery_status
    left_joins(:latest_state)
      .select("publishing_queue_items.*, publishing_pipeline_states.status")
  end

  def self.ensure_queued!(podcast)
    Rails.logger.info("Creating new PublishingQueueItem", {podcast_id: podcast.id})
    create!(podcast: podcast)
  end

  def self.settled_work?(podcast)
    current_unfinished_item(podcast).nil?
  end

  def self.current_unfinished_item(podcast)
    joins(:publishing_pipeline_states)
      .where(id: unfinished_items(podcast)).first
  end

  def self.unfinished_items(podcast)
    all_unfinished_items
      .where(podcast: podcast)
      .order(id: :desc)
  end

  def self.all_unfinished_items
    frag = <<~SQL
      (
        SELECT unfinished_podcast_items.* FROM
        (
          SELECT DISTINCT podcast_id
          FROM publishing_queue_items inner_pqi
        ) pqi
        JOIN LATERAL (
          SELECT * from publishing_queue_items
          WHERE id > COALESCE((SELECT max(publishing_queue_item_id)
                               FROM publishing_pipeline_states WHERE podcast_id = pqi.podcast_id AND status in (#{PublishingPipelineState.terminal_status_codes.join(",")})), -1)
          AND podcast_id = pqi.podcast_id
        ) unfinished_podcast_items ON TRUE
        ORDER BY unfinished_podcast_items.id DESC
      ) publishing_queue_items
    SQL

    from(frag)
  end

  def complete?
    most_recent_state&.complete?
  end

  def create_publish_job
    PublishFeedJob.perform_later(self)
  end
end
