require 'podcast_importer'

class PodcastImportJob < ActiveJob::Base

  queue_as :cms_default

  def perform(account_uri, podcast_uri)
    ActiveRecord::Base.connection_pool.with_connection do
      begin
        import_podcast(account_uri, podcast_uri)
      ensure
        if reschedule
          ReleaseEpisodesJob.set(wait: release_check_delay).perform_later(true)
        end
      end
    end
  end

  def import_podcast(account_uri, podcast_uri)
    pi = PodcastImporter.new(account_uri, podcast_uri)
    pi.import
  end
end
