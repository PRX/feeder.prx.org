namespace :feeder do
  desc "Publishes podcasts with episodes that are now released"
  task release_episodes: :environment do
    ReleaseEpisodesJob.perform_now
  end
end
