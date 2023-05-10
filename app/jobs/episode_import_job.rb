class EpisodeImportJob < ApplicationJob
  queue_as :feeder_default

  def perform(episode_import)
    episode_import.import
  end
end
