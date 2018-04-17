require 'addressable/uri'

class CopyMediaJob < ApplicationJob

  queue_as :feeder_default

  attr_accessor :media_resource

  def perform(media_resource)
    original_uri = Addressable::URI.parse(media_resource.original_url)
    if orig.scheme == 's3'
      s3_copy_resource(media_resource, original_uri)
    else
    end
  end

  def s3_copy_resource(media_resource, original_uri)
    orig_bucket = original_uri.host
    orig_key = original_uri.path.sub(/^\//, '')

    source = connection.bucket(orig_bucket).object(orig_key)
    destination = connection.bucket(feeder_storage_bucket).object(media_resource.destination_path)
    source.copy_to(destination, acl: 'public-read')
  end

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET']
  end

  def connection
    Aws::S3::Resource.new(
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      region: ENV['AWS_REGION']
    )
  end
end
