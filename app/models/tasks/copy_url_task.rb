require "faraday"
require "mimemagic"
require "aws-sdk"

class Tasks::CopyUrlTask < ::Task
  def start!
    data = download_file(options[:source])
    save_file(data)
    complete!
    owner.task_complete(self)
    HighwindsAPI::Content.purge_url(owner.url, false)
  rescue
    error!
  end

  def save_file(data)
    bucket = s3.bucket(feeder_storage_bucket)
    bucket.create(acl: "private", create_bucket_configuration: { location_constraint: ENV["AWS_REGION"] })

    opts = { body: data, content_type: content_type, acl: visibility }
    obj = bucket.object(options[:destination])
    obj.put(opts)
  end

  def content_type
    options[:content_type] || MimeMagic.by_path(options[:source])
  end

  def visibility
    options[:visibility] || "public-read"
  end

  def download_file(url)
    tmp = tempfile_for_url(url)
    response = http_connection.get(url)
    response.body
  end

  def http_connection
    Faraday.new { |b| b.adapter(Faraday.default_adapter) }
  end

  def s3
    o = {
      aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      region:  ENV["AWS_REGION"]
    }
    Aws::S3::Resource.new(o)
  end
end
