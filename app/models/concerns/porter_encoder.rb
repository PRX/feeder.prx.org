require 'active_support/concern'

module PorterEncoder
  extend ActiveSupport::Concern

  class_methods do
    def new_porter_sns_client
      Aws::SNS::Client.new
    end
  end

  def porter_start!(opts)
    opts = (opts || {}).with_indifferent_access
    job_id = SecureRandom.uuid

    job = {
      Id: job_id,
      Source: porter_source(opts[:source]),
      Tasks: [porter_copy(opts[:destination], opts[:source])],
      Callbacks: [porter_callback(opts[:callback])]
    }

    if opts[:job_type] == 'audio'
      job[:Tasks] << {Type: 'Inspect'}
    end

    porter_sns_client.publish({
      topic_arn: ENV['PORTER_SNS_TOPIC'],
      message: JSON.generate({Job: job})
    })

    job_id
  end

  private

  def porter_source(url)
    if url.starts_with?('s3://')
      parts = url.sub('s3://', '').split('/', 2)
      {Mode: 'AWS/S3', BucketName: parts[0], ObjectKey: parts[1]}
    elsif url.starts_with?('http')
      {Mode: 'HTTP', URL: url}
    else
      raise "Invalid porter source: #{url}"
    end
  end

  def porter_copy(url, src_url)
    if url.starts_with?('s3://')
      parts = url.sub('s3://', '').split('/', 2)
      s3_bucket = parts[0]
      s3_path = parts[1]
      filename = File.basename(src_url)

      # NOTE: for HTTP sources (NOT S3) - make sure the eventual encoding of
      # the CloudFront filename matches the source HTTP url
      if src_url.starts_with?('http')
        s3_path = CGI.unescape(s3_path)
        filename = CGI.unescape(filename)
      end

      {
        Type: 'Copy',
        Mode: 'AWS/S3',
        BucketName: s3_bucket,
        ObjectKey: s3_path,
        ContentType: 'REPLACE',
        Parameters: {
          CacheControl: 'max-age=86400',
          ContentDisposition: "attachment; filename=\"#{filename}\""
        }
      }
    else
      raise "Invalid porter destination: #{url}"
    end
  end

  def porter_callback(url)
    if url.starts_with?('sqs://')
      parts = url.sub('sqs://', '').split('/', 2)
      account_id = ENV['AWS_ACCOUNT_ID']
      {Type: 'AWS/SQS', Queue: "https://sqs.#{parts[0]}.amazonaws.com/#{account_id}/#{parts[1]}"}
    else
      raise "Invalid porter callback: #{url}"
    end
  end

  def porter_sns_client
    @porter_sns_client ||= self.class.new_porter_sns_client
  end

  def porter_sns_client=(client)
    @porter_sns_client = client
  end
end
