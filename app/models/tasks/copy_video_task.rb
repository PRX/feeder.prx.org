class Tasks::CopyVideoTask < Tasks::CopyMediaTask
  DEFAULT_MP3_BITRATE = 192

  def porter_tasks
    [].tap do |tasks|
      tasks << porter_inspect_task
      tasks << porter_copy_task
      tasks << porter_mp3_task
    end
  end

  # run a second job to generate a waveform for the transcoded mp3
  def porter_options
    super.tap do |opts|
      opts[:SerializedJobs] = [
        {
          Job: {
            Id: opts[:Id],
            Source: {
              Mode: "AWS/S3",
              BucketName: ENV["FEEDER_STORAGE_BUCKET"],
              ObjectKey: porter_escape(media_resource.variant_path("preview.mp3"))
            },
            Tasks: [porter_waveform_task],
            Callbacks: opts[:Callbacks]
          }
        }
      ]
    end
  end

  def handle_callback(new_status, time, msg)
    prev_results = porter_callback_task_results
    msg_results = Task.porter_callback_task_results(msg)
    all_results = (prev_results + msg_results).uniq
    super

    # HACKY: keep all results, regardless of callback order
    key = Task.porter_callback_key(result)
    result[key][:TaskResults] = all_results if key && all_results.any?

    # HACKY: keep in processing until both jobs finish
    if new_status == "complete"
      self.status =
        if %i[Inspect Waveform].all? { |k| porter_callback_task_result(k) }
          "complete"
        else
          "processing"
        end
    end
  end

  def porter_mp3_task
    {
      Type: "Transcode",
      Format: "mp3",
      Destination: {
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKey: porter_escape(media_resource.variant_path("preview.mp3")),
        ContentType: "REPLACE",
        Parameters: {
          CacheControl: "max-age=86400",
          ContentDisposition: "attachment; filename=\"#{porter_escape(media_resource.file_name + ".preview.mp3")}\""
        }
      },
      FFmpeg: {
        OutputFileOptions: "-b:a #{mp3_bitrate}k"
      }
    }
  end

  private

  # NOTE: need to specify something, to force converting to CBR
  def mp3_bitrate
    fmt = media_resource.episode&.podcast&.default_feed&.audio_format
    if fmt && fmt[:f] == "mp3"
      fmt[:b]
    else
      DEFAULT_MP3_BITRATE
    end
  end
end
