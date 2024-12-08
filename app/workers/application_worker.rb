require "prx/api"

class ApplicationWorker
  include Shoryuken::Worker

  def self.prefix_name(name)
    [prefix, application, name].join("_")
  end

  def self.application
    "feeder"
  end

  def self.prefix
    Rails.configuration.active_job.queue_name_prefix
  end

  def logger
    Shoryuken.logger
  end
end
