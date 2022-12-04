require 'shoryuken'
require 'shoryuken/extensions/active_job_adapter'

# # for older shoryuken, < 3.x, where celluloid is still used
# require 'say_when/poller/celluloid_poller'

# Shoryuken.on_start do
#   # check for new jobs to run every 5 seconds
#   SayWhen::Poller::CelluloidPoller.supervise as: :say_when, args: [5]
# end

Shoryuken.default_worker_options = {
  'queue' => "#{Rails.configuration.active_job.queue_name_prefix}_feeder_default",
  'auto_delete' => true,
  'auto_visibility_timeout' => true,
  'batch' => false,
  'body_parser' => :json
}

Shoryuken.configure_server do |_config|
  Rails.logger = Shoryuken::Logging.logger
  ActiveJob::Base.logger = Shoryuken::Logging.logger
  ActiveRecord::Base.logger = Shoryuken::Logging.logger
end

begin
  Shoryuken.configure_client do |_config|
    unless Rails.env.test?
      config_file = File.join(Rails.root, 'config', 'shoryuken.yml')
      Shoryuken::EnvironmentLoader.setup_options(config_file: config_file)
      if account_id = (Shoryuken.options[:aws][:account_id] || ENV['AWS_ACCOUNT_ID'])
        Shoryuken.sqs_client.account_id = account_id
      end
    end
  end
rescue StandardError => e
  Rails.logger.error('*** Shoryuken client failed to initialize. ***')
  Rails.logger.error(e)
end
