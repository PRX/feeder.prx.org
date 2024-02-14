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
    slice_media!
  end

  def slice_media!
    if media_resource.is_a?(Uncut) && media_resource.segmentation_ready?
      media_resource.slice_contents!
      media_resource.episode.contents.each(&:copy_media)
    end
  end
end
