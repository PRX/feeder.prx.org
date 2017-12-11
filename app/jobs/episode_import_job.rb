# encoding: utf-8

class EpisodeImportJob < ApplicationJob
  queue_as :cms_default

  def perform(episode_import)
    ActiveRecord::Base.connection_pool.with_connection do
      episode_import.import
    end
  end
end
