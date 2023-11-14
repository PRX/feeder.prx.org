class UnlinkJob < ApplicationJob
  queue_as :feeder_default

  def perform(key)
    s3_client.put_object(bucket: s3_bucket, key: key, body: "")
  end
end
