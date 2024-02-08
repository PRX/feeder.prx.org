class Tasks::FixMediaTask < ::Task
  before_save :update_media_resource, if: ->(t) { t.status_changed? && t.media_resource }

  def media_resource
    owner
  end

  def source_url
    media_resource&.href
  end

  def porter_tasks
    [
      {
        Type: "Transcode",
        Format: "INHERIT",
        Destination: {
          Mode: "AWS/S3",
          BucketName: ENV["FEEDER_STORAGE_BUCKET"],
          ObjectKey: porter_escape(media_resource.path)
        },
        FFmpeg: {
          OutputFileOptions: "-acodec copy"
        }
      }
    ]
  end

  def update_media_resource
    media_resource.status = status
    media_resource.save!
  end
end
