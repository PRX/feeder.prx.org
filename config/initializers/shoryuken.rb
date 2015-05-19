require 'logger'
require 'shoryuken'
require 'shoryuken/extensions/active_job_adapter'

Shoryuken.default_worker_options =  {
  'queue'                   => (ENV['RAILS_ENV'] || 'development') + '_feeder_default',
  'auto_delete'             => true,
  'auto_visibility_timeout' => true,
  'batch'                   => false,
  'body_parser'             => :json
}

Shoryuken::EnvironmentLoader.load(config_file: (Rails.root + 'config' + 'shoryuken.yml'))
