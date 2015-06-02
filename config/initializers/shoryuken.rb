require 'logger'
require 'shoryuken'
require 'shoryuken/extensions/active_job_adapter'

Shoryuken.configure_server do |config|
  # Replace Rails logger so messages are logged wherever Shoryuken is logging
  # Note: this entire block is only run by the processor, so we don't overwrite
  #       the logger when the app is running as usual.
  Rails.logger = Shoryuken::Logging.logger
  ActiveJob::Base.logger = Shoryuken::Logging.logger
  ActiveRecord::Base.logger = Shoryuken::Logging.logger

  # config.server_middleware do |chain|
  #   chain.add Shoryuken::MyMiddleware
  # end
end

Shoryuken.default_worker_options =  {
  'queue'                   => (ENV['RAILS_ENV'] || 'development') + '_feeder_default',
  'auto_delete'             => true,
  'auto_visibility_timeout' => true,
  'batch'                   => false,
  'body_parser'             => :json
}

Shoryuken::EnvironmentLoader.load(config_file: (Rails.root + 'config' + 'shoryuken.yml'))
