class ReleaseEpisodesJob < ActiveJob::Base

  queue_as :feeder_default

  def perform(reschedule = false)
    ActiveRecord::Base.connection_pool.with_connection do
      begin
        podcasts_to_release.tap do |podcasts|
          podcasts.each { |p| p.publish! }
        end
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

  def podcasts_to_release
    Podcast.
      joins(:episodes).
      where('podcasts.last_build_date < episodes.released_at').
      where('episodes.released_at <= now()').
      uniq.
      all
  end
end
