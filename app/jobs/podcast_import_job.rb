# encoding: utf-8

class PodcastImportJob < ApplicationJob
  queue_as :cms_podcast_import

  def perform(podcast_import, import_series = true)
    if import_series
      podcast_import.import_series!
    end
    podcast_import.import_episodes!
  end
end
