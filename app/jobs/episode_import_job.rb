class EpisodeImportJob < ApplicationJob
  queue_as :cms_podcast_import

  def perform(episode_import)
    episode_import.import
  end
end
