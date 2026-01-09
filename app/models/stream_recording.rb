class StreamRecording < ApplicationRecord
  ALL_DAYS = (0..6).to_a
  ALL_HOURS = (0..23).to_a

  enum :status, %w[enabled disabled paused].to_enum_h, prefix: true
  enum :create_as, %w[clips episodes].to_enum_h, prefix: true

  serialize :record_days, coder: JSON
  serialize :record_hours, coder: JSON

  belongs_to :podcast, -> { with_deleted }, touch: true, optional: true
  has_many :stream_resources, -> { order("start_at DESC") }, dependent: :destroy

  scope :active, ->(now = Time.now) { status_enabled.where("end_date IS NULL OR end_date > ?", now) }
  scope :recording, ->(now = Time.now) { active.where("start_date > ?", now) }

  validates :url, presence: true, http_url: true, http_head: /audio\/.+/
  validates :start_date, presence: true, if: :status_enabled?
  validates :end_date, comparison: {greater_than: :start_date}, allow_nil: true, if: :start_date
  validates :record_days, inclusion: {in: ALL_DAYS}, allow_nil: true
  validates :record_hours, inclusion: {in: ALL_HOURS}, allow_nil: true
  validates :expiration, numericality: {greater_than: 0}, allow_nil: true

  after_initialize :set_defaults
  after_save :write_config

  acts_as_paranoid

  def self.config
    active.map do |s|
      {
        id: s.id,
        podcast_id: s.podcast_id,
        url: s.url,
        start_date: s.start_date,
        end_date: s.end_date,
        record_days: s.record_days,
        record_hours: s.record_hours,
        callback: PorterUtils.callback_sqs
      }
    end
  end

  def set_defaults
    set_default(:status, "disabled")
    set_default(:create_as, "clips")
  end

  def write_config
    StreamRecordingConfigJob.perform_later
  end

  def record_days=(val)
    days = Array(val).reject(&:blank?).map(&:to_i).uniq.sort
    if days.empty? || days == ALL_DAYS
      super(nil)
    else
      super(days)
    end
  end

  def record_hours=(val)
    hours = Array(val).reject(&:blank?).map(&:to_i).uniq.sort
    if hours.empty? || hours == ALL_HOURS
      super(nil)
    else
      super(hours)
    end
  end
end
