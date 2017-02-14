require 'podcast_importer'

class PodcastImportJob < ActiveJob::Base

  queue_as :cms_default

  def perform(account_uri, podcast_uri)
    ActiveRecord::Base.connection_pool.with_connection do
      import_podcast(account_uri, podcast_uri)
    end
  end

  def import_podcast(account_uri, podcast_uri)
    pi = PodcastImporter.new(account_uri, podcast_uri)
    pi.import
  end
end
