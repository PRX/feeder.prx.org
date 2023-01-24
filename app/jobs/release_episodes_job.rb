class ReleaseEpisodesJob < ApplicationJob
  queue_as :feeder_default

  def perform(reschedule = false)
    Episode.release_episodes!
  ensure
    if reschedule
      ReleaseEpisodesJob.set(wait: release_check_delay).perform_later(true)
    end
  end

  def release_check_delay
    (ENV["FEEDER_RELEASE_CHECK_DELAY"] || 300).to_i
  end
end
