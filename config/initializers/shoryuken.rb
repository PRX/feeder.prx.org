require "shoryuken"
require "shoryuken/extensions/active_job_adapter"

Shoryuken.default_worker_options = {
  "queue" => "#{Rails.configuration.active_job.queue_name_prefix}_feeder_default",
  "auto_delete" => true,
  "auto_visibility_timeout" => true,
  "batch" => false,
  "body_parser" => :json
}

Shoryuken.configure_server do |_config|
  Shoryuken::Logging.logger = Rails.logger
  Shoryuken::Logging.logger.level = :info
end
