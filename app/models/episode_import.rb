class EpisodeImport < ApplicationRecord
  include ImportUtils

  store :config, coder: JSON

  belongs_to :episode, -> { with_deleted }, touch: true, optional: true
  belongs_to :podcast_import
  has_one :podcast, through: :podcast_import

  before_validation :set_defaults, on: :create

  enum :status, {
    created: CREATED,
    started: STARTED,
    importing: IMPORTING,
    complete: COMPLETE,
    invalid: INVALID,
    error: ERROR
  }, prefix: true

  scope :done, -> { where(status: [COMPLETE, INVALID, ERROR]) }
  scope :undone, -> { where.not.done }

  def set_defaults
    self.status ||= CREATED
  end

  def import!
  end

  def import_later
    EpisodeImportJob.perform_later(self)
  end

  def done?
    status_complete? && status_invalid? && status_error?
  end

  def undone?
    !done?
  end
end
