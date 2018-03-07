require 'newrelic_rpm'

class ApplicationJob < ActiveJob::Base

  rescue_from(StandardError) do |e|
    NewRelic::Agent.notice_error(e)
  end

  around_perform do |job, block|
    ActiveRecord::Base.connection_pool.with_connection do
      block.call
    end
  end
end
