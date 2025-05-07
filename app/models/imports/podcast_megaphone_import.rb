require "feedjira"

class PodcastMegaphoneImport < PodcastImport
  store :config, accessors: [:megaphone_podcast_id], coder: JSON

  has_many :episode_imports, dependent: :destroy, class_name: "EpisodeMegaphoneImport", foreign_key: :podcast_import_id

  def set_defaults
    super
  end

  def import!
    status_started!

    create_or_update_podcast!
    create_or_update_episode_imports!

    if episode_imports.any?
      status_importing!
    else
      status_complete!
    end
  rescue => err
    reset_podcast if podcast.invalid?
    status_error!
    unlock_podcast_later!
    raise err
  end

  def create_or_update_podcast!
    self.podcast ||= Podcast.new
  end

  def megaphone_feed
    return nil if podcast.blank?
    Feeds::MegaphoneFeed.where(podcast: podcast).first
  end

  def create_or_update_episode_imports!
  end
end
