# encoding: utf-8

class PodcastImportJob < ApplicationJob

  queue_as :cms_default

  def perform(podcast_import)
    ActiveRecord::Base.connection_pool.with_connection do
      podcast_import.import
    end
  end
end
