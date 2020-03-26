# encoding: utf-8

require 'aws-sdk'

module Portered
  extend ActiveSupport::Concern

  class_methods do
    def porter_callbacks(callbacks = nil)
      if callbacks.present?
        @porter_callbacks = Array.wrap(callbacks).map { |callback| format_callback(callback) }
      end
      @porter_callbacks
    end

    def format_callback(callback)
      if callback[:sqs].present?
        {
          Type: 'AWS/SQS',
          Queue: URI::HTTPS.build(
            host: "sqs.#{ENV['AWS_REGION']}.amazonaws.com",
            path: "/#{ENV['AWS_ACCOUNT_ID']}/#{callback[:sqs]}"
          ).to_s
        }
      elsif callback[:s3].present?
        uri = URI(callback[:s3])
        {
          Type: 'AWS/S3',
          BucketName: uri.host,
          ObjectPrefix: uri.path.sub(/^\//, '')
        }
      else
        callback
      end
    end
  end

  SNS_CLIENT = if ENV['PORTER_SNS_TOPIC_ARN']
                 Aws::SNS::Client.new
               elsif !Rails.env.test?
                 Rails.logger.warn('No Porter SNS topic provided - Porter jobs will be skipped.')
                 nil
               end

  def submit_porter_job(job_id, source_uri, task_array = nil)
    task_array = yield if block_given? && task_array.nil?

    publish_porter_sns(
      Job: {
        Id: job_id,
        Source: source_from_uri(source_uri),
        Tasks: Array.wrap(task_array),
        Callbacks: self.class.porter_callbacks
      }
    )
  end

  private

  def source_from_uri(url)
    uri = URI(url)
    case uri.scheme
    when 's3' then { Mode: 'AWS/S3', BucketName: uri.host, ObjectKey: uri.path.sub(/^\//, '') }
    else { Mode: 'HTTP', URL: url }
    end
  end

  def publish_porter_sns(message)
    return false if Rails.env.test? || !SNS_CLIENT.present?

    pp message

    SNS_CLIENT.publish(
      topic_arn: ENV['PORTER_SNS_TOPIC_ARN'],
      message: message.to_json
    )
  end

end
