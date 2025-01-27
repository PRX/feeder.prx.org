class PodcastImportJob < ApplicationJob
  queue_as :feeder_default

  def perform(podcast_import)
    podcast_import.import!
  rescue => err
    Rails.logger.error("PodcastImportJob error", error: err)
  end
end
