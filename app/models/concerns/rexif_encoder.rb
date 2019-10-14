require 'active_support/concern'

module RexifEncoder
  extend ActiveSupport::Concern

  class_methods do
    def new_rexif_sns_client
      Aws::SNS::Client.new
    end
  end

  def rexif_start!(opts)
    opts = (opts || {}).with_indifferent_access
    job_id = SecureRandom.uuid

    rexif_sns_client.publish({
      topic_arn: ENV['REXIF_JOB_EXECUTION_SNS_TOPIC'],
      message: JSON.generate({
        Job: {
          Id: job_id,
          Source: rexif_source(opts[:source]),
          Copy: {
            Destinations: [rexif_destination(opts[:destination])]
          },
          Callbacks: [rexif_callback(opts[:callback])]
        }
      })
    })

    job_id
  end

  private

  def rexif_source(url)
    if url.starts_with?('s3://')
      parts = url.sub('s3://', '').split('/', 2)
      {Mode: 'AWS/S3', BucketName: parts[0], ObjectKey: parts[1]}
    elsif url.starts_with?('http')
      {Mode: 'HTTP', URL: url}
    else
      raise "Invalid rexif source: #{url}"
    end
  end

  def rexif_destination(url)
    if url.starts_with?('s3://')
      parts = url.sub('s3://', '').split('/', 2)
      {Mode: 'AWS/S3', BucketName: parts[0], ObjectKey: parts[1]}
    else
      raise "Invalid rexif destination: #{url}"
    end
  end

  def rexif_callback(url)
    if url.starts_with?('sqs://')
      parts = url.sub('sqs://', '').split('/', 2)
      account_id = ENV['AWS_ACCOUNT_ID']
      {Type: 'AWS/SQS', Queue: "https://sqs.#{parts[0]}.amazonaws.com/#{account_id}/#{parts[1]}"}
    else
      raise "Invalid rexif callback: #{url}"
    end
  end

  def rexif_sns_client
    @rexif_sns_client ||= self.class.new_rexif_sns_client
  end

  def rexif_sns_client=(client)
    @rexif_sns_client = client
  end
end
