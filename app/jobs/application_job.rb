require 'newrelic_rpm'

class ApplicationJob < ActiveJob::Base

  rescue_from(StandardError) do |e|
    begin
      NewRelic::Agent.notice_error(e)
    ensure
      raise e
    end
  end

  around_perform do |job, block|
    ActiveRecord::Base.connection_pool.with_connection do
      block.call
    end
  end
end
