class EpisodeImport < ApplicationRecord
  include ImportUtils
  include EpisodeImportFilters

  store :config, coder: JSON

  belongs_to :episode, -> { with_deleted }, optional: true
  belongs_to :podcast_import, touch: true
  has_one :podcast, through: :podcast_import

  scope :filter_by_title, ->(text) { joins(:episode).where("episodes.title ILIKE ?", "%#{text}%") if text.present? }

  before_validation :set_defaults, on: :create
  after_update :set_podcast_import_status

  enum :status, {
    created: CREATED,
    started: STARTED,
    importing: IMPORTING,
    complete: COMPLETE,
    error: ERROR,
    not_found: NOT_FOUND,
    bad_timings: BAD_TIMINGS,
    no_media: NO_MEDIA,
    duplicate: DUPLICATE
  }, prefix: true

  def set_defaults
    self.status ||= CREATED
    self.config ||= {}
  end

  def set_podcast_import_status
    podcast_import.status_from_episodes! if status_previously_changed?
  end

  def import!
  end

  def import_later
    EpisodeImportJob.perform_later(self)
  end
end
