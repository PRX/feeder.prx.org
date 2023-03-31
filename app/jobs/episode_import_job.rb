class EpisodeImportJob < ApplicationJob
  queue_as :podcast_import

  def perform(episode_import)
    episode_import.import
  end
end
