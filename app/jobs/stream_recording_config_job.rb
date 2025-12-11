class StreamRecordingConfigJob < ApplicationJob
  S3_KEY = "streams.json"

  queue_as :feeder_default

  def perform
    s3_client.put_object(
      body: StreamRecording.config.to_json,
      bucket: s3_bucket,
      cache_control: "max-age=60",
      content_type: "application/json",
      key: S3_KEY
    )
  end
end
