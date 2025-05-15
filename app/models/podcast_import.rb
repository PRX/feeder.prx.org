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

      unlock_podcast_later! if done?
    end
  end

  def import!
  end

  def import_later
    PodcastImportJob.perform_later(self)
  end

  # keep podcast locked 1 minute for every 150 episode, so we're not publishing
  # on every single media-processed callback
  def unlock_podcast_later!
    lock_minutes = (episode_imports.count / 150.0).ceil
    podcast.update!(locked_until: Time.now + lock_minutes.minutes)
  end

  def parse_itunes_categories(categories)
    itunes_cats = {}
    Array(categories).map(&:strip).select { |c| !c.blank? }.each do |cat|
      if ITunesCategoryValidator.category?(cat)
        itunes_cats[cat] ||= []
      elsif (parent_cat = ITunesCategoryValidator.subcategory?(cat))
        itunes_cats[parent_cat] ||= []
        itunes_cats[parent_cat] << cat
      end
    end

    [itunes_cats.keys.map { |n| ITunesCategory.new(name: n, subcategories: itunes_cats[n]) }.first].compact
  end
end
