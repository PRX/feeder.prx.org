require 'shoryuken'
require 'shoryuken/extensions/active_job_adapter'

Shoryuken.default_worker_options =  {
  'queue'                   => "#{Rails.env}_feeder_default",
  'auto_delete'             => true,
  'auto_visibility_timeout' => true,
  'batch'                   => false,
  'body_parser'             => :json
}

Shoryuken.configure_server do |config|
  Rails.logger = Shoryuken::Logging.logger
  ActiveJob::Base.logger = Shoryuken::Logging.logger
  ActiveRecord::Base.logger = Shoryuken::Logging.logger
end

begin
  Shoryuken.configure_client do |config|
    unless Rails.env.test?
      config_file = File.join(Rails.root, 'config', 'shoryuken.yml')
      Shoryuken::EnvironmentLoader.load(config_file: config_file)
      Shoryuken::Client.account_id = Shoryuken.options[:aws][:account_id] || ENV['AWS_ACCOUNT_ID']
    end
  end
rescue StandardError => err
  Rails.logger.error("*** Shoryuken client failed to initialize. ***")
  Rails.logger.error(err)
end
