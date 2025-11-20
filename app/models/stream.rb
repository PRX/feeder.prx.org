class Stream < ApplicationRecord
  ALL_DAYS = (0..6).to_a
  ALL_HOURS = (0..23).to_a

  enum :status, %w[enabled disabled paused].to_enum_h, prefix: true
  enum :create_as, %w[clips episodes].to_enum_h, prefix: true

  serialize :record_days, coder: JSON
  serialize :record_hours, coder: JSON

  belongs_to :podcast, -> { with_deleted }, touch: true, optional: true

  scope :active, ->(now = Time.now) { all }
  scope :recording, ->(now = Time.now) { all }

  validates :url, presence: true, http_url: true
  validates :start_date, presence: true, if: :status_enabled?
  validates :end_date, comparison: {greater_than: :start_date}, allow_nil: true, if: :start_date
  validates :record_days, inclusion: {in: ALL_DAYS}, allow_nil: true
  validates :record_hours, inclusion: {in: ALL_HOURS}, allow_nil: true
  validates :expiration, numericality: {greater_than: 0}, allow_nil: true

  after_initialize :set_defaults

  acts_as_paranoid

  def set_defaults
    set_default(:status, "disabled")
    set_default(:create_as, "clips")
  end

  def record_days
    super || ALL_DAYS
  end

  def record_days=(val)
    days = Array(val).reject(&:blank?).map(&:to_i)
    if days.empty? || days == ALL_DAYS
      super(nil)
    else
      super(days)
    end
  end

  def record_hours
    super || ALL_HOURS
  end

  def record_hours=(val)
    hours = Array(val).reject(&:blank?).map(&:to_i)
    if hours.empty? || hours == ALL_HOURS
      super(nil)
    else
      super(hours)
    end
  end
end
