# encoding: utf-8

class PodcastImportJob < ApplicationJob
  queue_as :cms_default

  def perform(podcast_import)
    podcast_import.import
  end
end
