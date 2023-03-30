class PodcastImportJob < ApplicationJob
  queue_as :cms_podcast_import

  def perform(podcast_import, import_podcast = true)
    if import_podcast
      podcast_import.import_podcast!
    end
    podcast_import.import_episodes!
  end
end
