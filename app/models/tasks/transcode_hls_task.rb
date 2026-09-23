class Tasks::TranscodeHlsTask < ::Task
  def media_resource
    owner
  end

  def source_url
    media_resource&.original_url
  end

  def porter_tasks
    [].tap do |tasks|
      tasks << porter_hls_task
    end
  end

  def update_owner
    media_resource.status = status

    # change status, if metadata doesn't pass validations
    media_resource.status = "invalid" if complete? && media_resource.invalid?

    media_resource.save!
    media_resource.after_hls_transcode(self) if media_resource.status_complete?
  end

  private

  def porter_hls_task
    {
      Type: "HLS",
      Preset: "Standard Podcast 2026 v1",
      AdBreaks: hls_ad_breaks,
      Destination: {
        Mode: "AWS/S3",
        BucketName: ENV["FEEDER_STORAGE_BUCKET"],
        ObjectKeyPrefix: media_resource.variant_path(""),
        Parameters: {
          CacheControl: "max-age=86400",
          ContentDisposition: "attachment; filename=\"#{porter_escape(media_resource.file_name)}\""
        }
      }
    }
  end

  # NOTE: HLS task doesn't support pre/post or cutting content out of midroll break
  def hls_ad_breaks
    media_resource.segmentation[0...-1].map(&:last)
  end
end
