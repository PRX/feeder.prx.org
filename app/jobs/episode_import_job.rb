class EpisodeImportJob < ApplicationJob
  queue_as :feeder_default

  def perform(episode_import)
    episode_import.import!
  rescue => err
    Rails.logger.error("EpisodeImportJob error", error: err)
  end
end
