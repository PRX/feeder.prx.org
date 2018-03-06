require 'newrelic_rpm'

class ApplicationJob < ActiveJob::Base
  around_perform :use_db_pool

  rescue_from(StandardError) do |e|
    NewRelic::Agent.notice_error(e)
  end

  def use_db_pool(job)
    ActiveRecord::Base.connection_pool.with_connection do
      yield
    end
  end
end
