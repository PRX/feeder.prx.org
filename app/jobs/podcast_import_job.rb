class PodcastImportJob < ApplicationJob
  queue_as :feeder_default

  def perform(podcast_import)
    podcast_import.import!
  end
end
