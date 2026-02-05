class StreamRecording < ApplicationRecord
  ALL_DAYS = (0..6).to_a
  ALL_HOURS = (0..23).to_a
  ALL_PLACEHOLDER = "all"

  enum :status, %w[enabled disabled paused].to_enum_h, prefix: true
  enum :create_as, %w[clips].to_enum_h, prefix: true

  serialize :record_days, coder: JSON
  serialize :record_hours, coder: JSON

  belongs_to :podcast, -> { with_deleted }, touch: true, optional: true
  has_many :stream_resources, dependent: :destroy

  scope :active, ->(now = Time.now) { status_enabled.where("end_date IS NULL OR end_date > ?", now) }
  scope :recording, ->(now = Time.now) { active.where("start_date > ?", now) }

  validates :url, presence: true, http_url: true, http_head: /audio\/.+/
  validates :end_date, comparison: {greater_than: :start_date}, allow_nil: true, if: :start_date
  validates :record_days, inclusion: {in: ALL_DAYS}, allow_nil: true
  validates :record_hours, inclusion: {in: ALL_HOURS}, allow_nil: true
  validates :expiration, numericality: {greater_than: 0}, allow_nil: true
  validates :time_zone, inclusion: {in: ActiveSupport::TimeZone.all.map(&:name)}, allow_nil: true

  after_initialize :set_defaults
  after_save :write_config

  acts_as_paranoid

  def self.config
    active.map(&:config)
  end

  def config
    attrs = slice(%i[id podcast_id url start_date end_date record_days record_hours]).compact
    attrs[:callback] = PorterUtils.callback_sqs

    # use canonical timezones, rather than activesupport human-readable names
    if time_zone.present?
      attrs[:time_zone] = ActiveSupport::TimeZone[time_zone].tzinfo.canonical_identifier
    end

    attrs
  end

  def set_defaults
    set_default(:status, "disabled")
    set_default(:create_as, "clips")
  end

  def write_config
    StreamRecordingConfigJob.perform_later
  rescue => err
    raise err unless Rails.env.development?
  end

  def record_days=(val)
    days = (Array(val) - ["all"]).reject(&:blank?).map(&:to_i).uniq.sort
    if days.empty? || days == ALL_DAYS || days.include?(ALL_PLACEHOLDER)
      super(nil)
    else
      super(days)
    end
  end

  def record_hours=(val)
    hours = (Array(val) - ["all"]).reject(&:blank?).map(&:to_i).uniq.sort
    if hours.empty? || hours == ALL_HOURS || hours.include?(ALL_PLACEHOLDER)
      super(nil)
    else
      super(hours)
    end
  end
end
