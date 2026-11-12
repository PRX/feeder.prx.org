class Tasks::SliceMediaTask < Tasks::CopyMediaTask
  def source_url
    media_resource.original_url
  end

  def porter_tasks
    [].tap do |tasks|
      tasks << porter_inspect_task
      tasks << porter_slice_task
    end
  end

  def set_media_metadata
    super

    # use size/duration we sliced, not of the inspected original file
    media_resource.file_size = porter_callback_transcode[:Size]&.to_i
    media_resource.duration = porter_callback_transcode[:Duration]&.to_f&./ 1000
  end

  def porter_slice_task
    output_opts = ["-map_metadata 0", "-c copy"]
    output_opts << "-ss #{media_resource.slice_start}" if media_resource.slice_start.present?
    output_opts << "-to #{media_resource.slice_end}" if media_resource.slice_end.present?

    {
      Type: "Transcode",
      Format: "INHERIT",
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
        OutputFileOptions: output_opts.join(" ")
      }
    }
  end
end
