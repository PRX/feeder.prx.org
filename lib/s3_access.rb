# frozen_string_literal: true

# Provide methods to access s3
module S3Access
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

  def s3_save_file(body, key, options = {})
    options[:body] = body
    options[:key] = key
    options[:bucket] ||= s3_bucket
    s3_client.put_object(options)
  end

  def s3_copy_file(source, key, options = {})
    options[:copy_source] = source
    options[:key] = key
    options[:bucket] ||= s3_bucket
    s3_client.copy_object(options)
  end
end
