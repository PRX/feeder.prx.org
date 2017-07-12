require 'say_when'

# Specify a logger for SayWhen
SayWhen.logger = Rails.logger

# Configure the scheduler for how to store and process scheduled jobs
# it will default to a :memory strategy and :simple processor
SayWhen.configure do |options|
  # options[:storage_strategy]   = :memory
  options[:storage_strategy] = :active_record

  # options[:processor_strategy] = :simple
  options[:processor_strategy] = :active_job

  options[:queue] = :feeder_default
end

begin
  SayWhen.schedule(
    group: 'application',
    name: 'release_episodes',
    trigger_strategy: 'cron',
    trigger_options: { expression: '0 0/5 * * * ?', time_zone: 'UTC' },
    job_class: 'Episode',
    job_method: 'release_episodes!'
  )
rescue ActiveRecord::StatementInvalid => ex
  puts "Failed to init say_when job: #{ex.inspect}"
end

# # for use with Shoryuken >= 3.x
# require 'say_when/poller/concurrent_poller'
# poller = SayWhen::Poller::ConcurrentPoller.new(5)
# poller.start
