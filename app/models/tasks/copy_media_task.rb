class Tasks::CopyMediaTask < ::Task
  before_save :update_media_resource, if: ->(t) { t.status_changed? && t.media_resource }

  def media_resource
    owner
  end

  def source_url
    if media_resource&.slice?
      media_resource.original_url
    else
      media_resource&.href
    end
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

      # if we sliced the file, override the size/duration
      if media_resource.slice?
        porter_callback_inspect[:Size]&.to_i
        media_resource.file_size = porter_callback_transcode[:Size]&.to_i
        media_resource.duration = porter_callback_transcode[:Duration]&.to_f&./ 1000
      end

      # change status, if metadata doesn't pass validations
      media_resource.status = "invalid" if media_resource.invalid?
    end

    media_resource.save!

    if media_resource.status_complete? && bad_audio?
      fix_media!
    else
      slice_media!
    end
  end

  def fix_media!
    media_resource.status = "processing"
    media_resource.save!

    # set an explicit format for ffmpeg to use if possible
    fmt = porter_callback_inspect.dig(:Audio, :Format) || porter_callback_inspect.dig(:Video, :Format)

    # set an explicit bitrate if vbr
    bit = next_highest_bitrate if bad_audio_vbr?

    Tasks::FixMediaTask.create!(owner: owner, media_format: fmt, media_bitrate: bit).start!
  end

  def slice_media!
    if media_resource.is_a?(Uncut) && media_resource.segmentation_ready?
      media_resource.slice_contents!
      media_resource.episode.contents.each(&:copy_media)
    end
  end

  def next_highest_bitrate
    bitrate = porter_callback_inspect.dig(:Audio, :Bitrate).to_i / 1000
    if bitrate > 0
      higher_bits = AudioFormatValidator::BIT_RATES.select { |b| b >= bitrate }
      higher_bits.first || AudioFormatValidator::BIT_RATES.last
    else
      128
    end
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

  def porter_waveform_task
    {
      Type: "Waveform",
      Generator: "BBC/audiowaveform/v1.x",
      DataFormat: "JSON",
      Destination: {
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKey: porter_escape(media_resource.waveform_path),
        Parameters: {
          CacheControl: "max-age=86400",
          ContentDisposition: "attachment; filename=\"#{porter_escape(media_resource.waveform_file_name)}\"",
          ContentType: "application/json"
        }
      },
      WaveformPointBitDepth: 8
    }
  end
end
