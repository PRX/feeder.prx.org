require "newrelic_rpm"

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  rescue_from(StandardError) do |e|
    NewRelic::Agent.notice_error(e)
  ensure
    if e.is_a? ActiveJob::DeserializationError
      Rails.logger.warn(e.message)
    else
      raise e
    end
  end
end
