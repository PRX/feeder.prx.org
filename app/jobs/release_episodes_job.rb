class ReleaseEpisodesJob < ActiveJob::Base

  queue_as :feeder_default

  def perform(reschedule = false)
    ActiveRecord::Base.connection_pool.with_connection do
      begin
        release_podcasts!
      ensure
        if reschedule
          ReleaseEpisodesJob.set(wait: release_check_delay).perform_later(true)
        end
      end
    end
  end

  def release_check_delay
    (ENV['FEEDER_RELEASE_CHECK_DELAY'] || 300).to_i
  end

  def release_podcasts!
    podcasts = []
    episodes_to_release.each do |e|
      podcasts << e.podcast
      e.touch
    end
    podcasts.uniq.each { |p| p.publish! }
  end

  def episodes_to_release
    Episode.where('published_at > updated_at AND published_at <= now()').all
  end
end
