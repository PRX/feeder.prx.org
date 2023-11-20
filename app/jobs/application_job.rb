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

  def s3_bucket
    ENV["FEEDER_STORAGE_BUCKET"]
  end

  def s3_client
    if Rails.env.test? || ENV["AWS_ACCESS_KEY_ID"].present?
      Aws::S3::Client.new(
        credentials: Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"]),
        region: ENV["AWS_REGION"]
      )
    else
      Aws::S3::Client.new
    end
  end
end
