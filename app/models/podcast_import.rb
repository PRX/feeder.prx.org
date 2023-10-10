class PodcastImport < ApplicationRecord
  include ImportUtils

  store :config, coder: JSON

  belongs_to :podcast, -> { with_deleted }, touch: true, optional: true, autosave: true
  has_many :episode_imports, dependent: :destroy

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
  scope :undone, -> { where.not(status: [COMPLETE, INVALID, ERROR]) }

  def set_defaults
    self.status ||= CREATED
    self.config ||= {}
  end

  def status_from_episodes!
    stats = episode_imports.group(:status).count

    if (stats.keys - [COMPLETE, INVALID, ERROR]).empty?
      if stats[ERROR]
        status_error!
      elsif stats[INVALID]
        status_invalid!
      else
        status_complete!
      end
    else
      status_importing!
    end

    unlock_podcast! if done?
  end

  def import!
  end

  def import_later
    PodcastImportJob.perform_later(self)
  end

  def done?
    status_complete? && status_invalid? && status_error?
  end

  def undone?
    !done?
  end

  def unlock_podcast!
    podcast.update!(locked: false)
  end
end
