require 'addressable/uri'

class CopyImageJob < ApplicationJob

  queue_as :feeder_default

  attr_accessor :image

  def perform(image)
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
