class Tasks::FixMediaTask < ::Task
  attr_accessor :media_format, :media_bitrate

  def self.start!(owner, copy_task)
    fix = new(owner: owner)

    # set an explicit format for ffmpeg to use if possible
    fix.media_format = copy_task.porter_callback_format

    # set an explicit bitrate if vbr
    fix.media_bitrate = copy_task.porter_callback_bitrate_normalized if copy_task.bad_audio_vbr?

    # keep media in processing status, since this task always comes after a completed copy
    owner.update!(status: "processing")

    fix.start!
  end

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
          OutputFileOptions: media_bitrate ? "-b:a #{media_bitrate}k" : "-acodec copy"
        }
      }
    ]
  end

  def update_owner
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
