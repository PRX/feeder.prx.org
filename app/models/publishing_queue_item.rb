class PublishingQueueItem < ApplicationRecord
  scope :max_id_grouped, -> { group(:podcast_id).select("max(id) as id") }
  scope :latest_attempted, -> { joins(:publishing_pipeline_states).order("publishing_pipeline_states.id desc") }
  scope :latest_completed, -> { latest_attempted.where(publishing_pipeline_states: {status: PublishingPipelineState::TERMINAL_STATUSES}) }

  # Has at most two publishing attempt logs: one when initiated and one when completed
  has_many :publishing_pipeline_states
  has_one :latest_attempt, -> { order(id: :desc) }, class_name: "PublishingPipelineState"
  belongs_to :podcast

  def self.ensure_queued!(podcast)
    create!(podcast: podcast)
  end

  def self.settled_work?(podcast)
    # test that there is no publishing attempt in progress
    unfinished_attempted_item(podcast).nil?
  end

  def self.unfinished_attempted_item(podcast)
    # test that there is no publishing attempt in progress
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
                               FROM publishing_pipeline_states WHERE podcast_id = pqi.podcast_id AND status in (#{PublishingPipelineState::TERMINAL_STATUSES.join(",")})), -1)
          AND podcast_id = pqi.podcast_id
        ) unfinished_podcast_items ON TRUE
      ) publishing_queue_items
    SQL

    from(frag)
  end

  def complete?
    latest_attempt&.complete?
  end

  def create_publish_job
    PublishFeedJob.perform_later(self)
  end
end
