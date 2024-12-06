class Tasks::FixMediaTask < ::Task
  before_save :update_media_resource, if: ->(t) { t.status_changed? && t.media_resource }

  attr_accessor :media_format, :media_bitrate

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
        Format: media_format || "INHERIT",
        Destination: {
          Mode: "AWS/S3",
          BucketName: ENV["FEEDER_STORAGE_BUCKET"],
          ObjectKey: porter_escape(media_resource.path),
          ContentType: "REPLACE",
          Parameters: {
            CacheControl: "max-age=86400",
            ContentDisposition: "attachment; filename=\"#{porter_escape(media_resource.file_name)}\""
          }
        },
        FFmpeg: {
          OutputFileOptions: media_bitrate ? "-acodec copy -b:a #{media_bitrate}k" : "-acodec copy"
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
