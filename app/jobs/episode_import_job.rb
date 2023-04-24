class EpisodeImportJob < ApplicationJob
  queue_as :feeder_podcast_import

  def perform(episode_import)
    episode_import.import
  end
end
