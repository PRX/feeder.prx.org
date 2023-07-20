require "active_support/concern"

module PorterUtils
  extend ActiveSupport::Concern

  class_methods do
    def porter_sns_client
      @porter_sns_client ||= Aws::SNS::Client.new(region: porter_region)
    end

    def porter_region
      arn = ENV["PORTER_SNS_TOPIC"] || ""
      match_data = arn.match(/arn:aws:sns:(?<region>.+):\d+:.+/) || {}
      match_data[:region] || ENV["AWS_REGION"]
    end
  end

  def porter_start!(job)
    self.class.porter_sns_client.publish(topic_arn: ENV["PORTER_SNS_TOPIC"], message: {Job: job}.to_json)
  end

  def porter_source
    if source_url&.starts_with?("s3://")
      parts = source_url.sub("s3://", "").split("/", 2)
      {Mode: "AWS/S3", BucketName: parts[0], ObjectKey: parts[1]}
    elsif source_url&.starts_with?("http")
      {Mode: "HTTP", URL: source_url}
    else
      raise "Invalid porter source url: #{source_url}"
    end
  end

  def porter_tasks
    []
  end

  def porter_callbacks
    region = ENV["AWS_REGION"].present? ? ENV["AWS_REGION"] : "us-east-1"
    account = ENV["AWS_ACCOUNT_ID"]
    queue = ApplicationWorker.prefix_name("fixer_callback")

    [
      {
        Type: "AWS/SQS",
        Queue: "https://sqs.#{region}.amazonaws.com/#{account}/#{queue}"
      }
    ]
  end

  # NOTE: for HTTP sources (NOT S3) - make sure the eventual encoding of
  # the CloudFront filename/path matches the source HTTP url
  def porter_escape(str)
    if source_url&.starts_with?("http")
      CGI.unescape(str)
    else
      str
    end
  end
end
