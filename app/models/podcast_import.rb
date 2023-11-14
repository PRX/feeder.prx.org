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
    error: ERROR
  }, prefix: true

  def set_defaults
    self.status ||= CREATED
    self.config ||= {}
  end

  def file_name
  end

  def status_from_episodes!
    with_lock do
      stats = episode_imports.group(:status).count

      if (stats.keys - ALL_DONE).empty?
        if stats.keys.empty? || stats.keys == [COMPLETE]
          status_complete!
        else
          status_error!
        end
      else
        status_importing!
      end

      unlock_podcast! if done?
    end
  end

  def import!
  end

  def import_later
    PodcastImportJob.perform_later(self)
  end

  def unlock_podcast!
    podcast.update!(locked: false)
  end
end
