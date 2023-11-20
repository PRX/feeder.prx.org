class UnlinkJob < ApplicationJob
  queue_as :feeder_default

  def perform(key)
    s3_client.delete_object(bucket: s3_bucket, key: key)
  end
end
