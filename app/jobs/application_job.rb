require 'newrelic_rpm'

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  rescue_from(StandardError) do |e|
    NewRelic::Agent.notice_error(e)
  ensure
    raise e
  end

  around_perform do |_job, block|
    ActiveRecord::Base.connection_pool.with_connection do
      block.call
    end
  end
end
