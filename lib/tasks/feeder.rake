namespace :feeder do
  desc "Publishes podcasts with episodes that are now released"
  task :release_episodes => :environment do
    puts "rake: release_episodes start"
    ReleaseEpisodesJob.perform_now
    puts "rake: release_episodes end"
  end
end
