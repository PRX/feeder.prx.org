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
    invalid: INVALID,
    error: ERROR
  }, prefix: true

  scope :done, -> { where(status: [COMPLETE, INVALID, ERROR]) }
  scope :undone, -> { where.not(status: [COMPLETE, INVALID, ERROR]) }

  def set_defaults
    self.status ||= CREATED
    self.config ||= {}
  end

  def all_media_status
    episode.media.append(episode.uncut).concat(episode.images).compact.map(&:status)
  end

  def status_from_media!
    stats = all_media_status

    if stats.include?(ERROR)
      status_error!
    elsif stats.include?(INVALID)
      status_invalid!
    elsif stats.empty? || stats.all?(COMPLETE)
      status_complete!
    else
      status_importing!
    end

    podcast_import.status_from_episodes! if status_previously_changed?
  end

  def import!
  end

  def import_later
    EpisodeImportJob.perform_later(self)
  end

  def done?
    status_complete? || status_invalid? || status_error?
  end

  def undone?
    !done?
  end
end
