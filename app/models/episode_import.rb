class EpisodeImport < ApplicationRecord
  include ImportUtils

  store :config, coder: JSON

  belongs_to :episode, -> { with_deleted }, touch: true, optional: true
  belongs_to :podcast_import
  has_one :podcast, through: :podcast_import

  scope :non_duplicates, -> { where(has_duplicate_guid: false) }
  scope :having_duplicate_guids, -> { where(has_duplicate_guid: true) }

  before_validation :set_defaults, on: :create

  enum :status, {
    created: CREATED,
    started: STARTED,
    importing: IMPORTING,
    complete: COMPLETE,
    error: ERROR
  }, prefix: true

  scope :done, -> { where(status: [COMPLETE, ERROR]) }
  scope :undone, -> { where.not(status: [COMPLETE, ERROR]) }

  def set_defaults
    self.status ||= CREATED
    self.config ||= {}
  end

  def import!
  end

  def import_later
    EpisodeImportJob.perform_later(self)
  end

  def done?
    status_complete? || status_error?
  end

  def undone?
    !done?
  end
end
