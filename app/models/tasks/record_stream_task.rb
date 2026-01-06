class Tasks::RecordStreamTask < ::Task
  before_save :update_stream_resource, if: ->(t) { t.status_changed? && t.stream_resource }

  def stream_resource
    owner
  end

  def self.from_job_id(job_id)
    task = build(job_id: job_id)

    if task.job_id_valid?
      rec = StreamRecording.with_deleted.find_by_id(task.stream_recording_id)
      return unless rec

      # find or build resources for this time range
      params = {start_at: task.start_at, end_at: task.end_at}
      res = rec.stream_resources.with_deleted.find_by(params) || rec.stream_resources.build(params)
      task.owner = res
      task
    end
  end

  def update_stream_resource
    stream_resource.status = status

    if complete?
      porter_callback_ffmpeg_output

      # TODO: i guess decide if we're going to use this file
      # (it's larger/better than the current stream_resource audio)
      # then reset the stream_resource original_url to this source

      # TODO: decide if we captured the entire timeframe? or is this just a method?
      # stream_resource.status = "incomplete" if stream_resource.incomplete?
    end

    stream_resource.save!

    if stream_resource.status_complete?
      # TODO: copy from the stream recorder's source S3 to our Feeder S3, and generate a waveform
      # but ONLY IF this file is >= the previous one attached to the StreamResource
    end
  end

  # parsing data from the job_id
  # <podcast_id>/<stream_recording_id>/<start_at>/<end_at>/<guid>.<ext>
  def job_id_parts
    (job_id || "").split("/")
  end

  def podcast_id
    job_id_parts[0].to_i if job_id_parts[0].to_i > 0
  end

  def stream_recording_id
    job_id_parts[1].to_i if job_id_parts[1].to_i > 0
  end

  def start_at
    job_id_parts[2]&.to_time
  rescue
    nil
  end

  def end_at
    job_id_parts[3]&.to_time
  rescue
    nil
  end

  def file_name
    job_id_parts[4]
  end

  def job_id_valid?
    podcast_id && stream_recording_id && start_at && end_at && file_name
  end

  # parsing data from the FFmpeg task result
  def source_bucket
    porter_callback_ffmpeg_output.try(:[], :BucketName)
  end

  def source_key
    porter_callback_ffmpeg_output.try(:[], :ObjectKey)
  end

  def source_size
    porter_callback_ffmpeg_output.try(:[], :Size)
  end

  def source_duration
    porter_callback_ffmpeg_output.try(:[], :Duration)
  end

  def source_start_at
    start_epoch = porter_callback_ffmpeg_output.try(:[], :StartEpoch)
    Time.at(start_epoch).utc if start_epoch
  end

  def source_end_at
    source_start_at + Rational(source_duration, 1000) if source_start_at && source_duration
  end
end
