require "active_support/concern"

module CopyResource
  extend ActiveSupport::Concern

  # synchronously copy files from one media resource to another
  def copy_resource_to(to_resource)
    return unless status_complete?

    orig = copy_resource_s3(path, to_resource.path) || copy_resource_http(url, to_resource.path)
    to_resource.original_url = orig

    if generate_waveform? && to_resource.generate_waveform?
      copy_resource_s3(waveform_path, to_resource.waveform_path) || copy_resource_http(waveform_url, to_resource.waveform_path)
    end

    %i[bit_rate channels duration file_size medium mime_type sample_rate segmentation status].each do |k|
      if respond_to?(k) && to_resource.respond_to?(:"#{k}=")
        to_resource.send(:"#{k}=", send(k))
      end
    end

    to_resource
  rescue => err
    Rails.logger.error("copy_resource_to error", error: err)
    NewRelic::Agent.notice_error(err)
    to_resource.status = "error"
    to_resource
  end

  def copy_resource_s3_client
    Aws::S3::Client.new(stub_responses: Rails.env.test?)
  end

  private

  # S3 copying will be faster
  def copy_resource_s3(from_path, to_path)
    bucket = ENV["FEEDER_STORAGE_BUCKET"]
    from_src = "/#{bucket}/#{from_path}"
    copy_resource_s3_client.copy_object(bucket: bucket, key: to_path, copy_source: from_src)
    "s3://#{bucket}/#{from_path}"
  rescue Aws::S3::Errors::NoSuchKey
    nil
  end

  # but for local dev, your db resources may be in different buckets/accounts
  def copy_resource_http(from_url, to_path)
    resp = Faraday.get(from_url)
    if resp.success?
      copy_resource_s3_client.put_object(bucket: ENV["FEEDER_STORAGE_BUCKET"], key: to_path, body: resp.body)
      from_url
    else
      raise "Got #{resp.status} from #{from_url}"
    end
  end
end
