class Tasks::CopyMediaTask < ::Task
  before_save :update_media_resource, if: ->(t) { t.status_changed? && t.media_resource }

  def media_resource
    owner
  end

  def source_url
    media_resource&.href
  end

  def porter_tasks
    tasks = [{Type: "Inspect"}]
    tasks << porter_copy_task unless media_resource.slice?
    tasks << porter_slice_task if media_resource.slice?
    tasks << porter_waveform_task if media_resource.generate_waveform?
    tasks
  end

  def update_media_resource
    media_resource.status = status

    if complete?
      info = porter_callback_inspect
      media_resource.mime_type = porter_callback_mime
      media_resource.medium = (media_resource.mime_type || "").split("/").first
      media_resource.file_size = porter_callback_size

      if info[:Audio]
        media_resource.sample_rate = info[:Audio][:Frequency].to_i
        media_resource.channels = info[:Audio][:Channels].to_i
        media_resource.duration = info[:Audio][:Duration].to_f / 1000
        media_resource.bit_rate = info[:Audio][:Bitrate].to_i / 1000
      end

      # only return for actual videos - not detected images in id3 tags
      if info[:Video] && media_resource.mime_type&.starts_with?("video")
        media_resource.duration = info[:Video][:Duration].to_f / 1000
        media_resource.width = info[:Video][:Width].to_i
        media_resource.height = info[:Video][:Height].to_i
        media_resource.frame_rate = info[:Video][:Framerate].to_f.round
      end

      # change status, if metadata doesn't pass validations
      media_resource.status = "invalid" if media_resource.invalid?
    end

    media_resource.save!
  end

  private

  def porter_inspect_task
    {Type: "Inspect"}
  end

  def porter_copy_task
    {
      Type: "Copy",
      Mode: "AWS/S3",
      BucketName: ENV["FEEDER_STORAGE_BUCKET"],
      ObjectKey: porter_escape(media_resource.path),
      ContentType: "REPLACE",
      Parameters: {
        CacheControl: "max-age=86400",
        ContentDisposition: "attachment; filename=\"#{porter_escape(media_resource.file_name)}\""
      }
    }
  end

  # TODO: what happens to id3 on sliced files? will the 1st segment still have it?
  def porter_slice_task
    {
      Type: "Transcode",
      Destination: {
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKey: porter_escape(media_resource.path)
      },
      FFmpeg: {
        InputFileOptions: media_resource.slice_start.nil? ? "" : "-ss #{media_resource.slice_start}",
        OutputFileOptions: media_resource.slice_end.nil? ? "" : "-t #{media_resource.slice_end}"
      }
    }
  end

  def porter_waveform_task
    {
      Type: "Waveform",
      Generator: "BBC/audiowaveform/v1.x",
      DataFormat: "JSON",
      Destination: {
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKey: porter_escape(media_resource.waveform_path)
      },
      WaveformPointBitDepth: 8
    }
  end
end
