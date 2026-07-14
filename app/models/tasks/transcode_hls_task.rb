class Tasks::TranscodeHlsTask < Tasks::CopyMediaTask
  DEFAULT_MP3_BITRATE = 192

  def source_url
    media_resource&.href
  end

  def source_file_name
  end

  def porter_tasks
    [].tap do |tasks|
      tasks << porter_inspect_task
      tasks << porter_copy_task
      tasks << porter_mp3_task
      # TODO: tasks << porter_apple_hls_task
    end
  end

  private

  # create an mp3 version of the video, for the plain enclosure url
  def porter_mp3_task
    {
      Type: "Transcode",
      Format: "mp3",
      Destination: {
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKey: porter_escape(media_resource.rendition_path("audio.mp3")),
        ContentType: "REPLACE",
        Parameters: {
          CacheControl: "max-age=86400",
          ContentDisposition: "attachment; filename=\"#{porter_escape(media_resource.file_name + ".mp3")}\""
        }
      },
      FFmpeg: {
        OutputFileOptions: "-b:a #{mp3_bitrate}k"
      }
    }
  end

  # NOTE: need to specify something, to force converting to CBR
  def mp3_bitrate
    fmt = media_resource.episode&.podcast&.default_feed&.audio_format
    if fmt && fmt[:f] == "mp3"
      fmt[:b]
    else
      DEFAULT_MP3_BITRATE
    end
  end

  # TODO: transcode index.m3u8 and renditions
  def porter_apple_hls_task
  end
end
