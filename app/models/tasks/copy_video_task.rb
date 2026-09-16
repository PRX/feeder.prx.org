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

  def result=(msg)
    prev_results = porter_callback_task_results
    super

    # HACKY: keep previous job results, when the waveform job runs
    key = self.class.porter_callback_key(result)
    merged_results = (prev_results + porter_callback_task_results).uniq
    result[key][:TaskResults] = merged_results if key && merged_results.any?

    # HACKY: keep in processing until waveform finishes
    self.status = "processing" if complete? && !porter_callback_task_result(:Waveform)
  end

  private

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
