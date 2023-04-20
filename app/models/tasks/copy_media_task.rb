class Tasks::CopyMediaTask < ::Task
  before_save do
    if media_resource && status_changed?
      if complete?
        meta = porter_callback_media_meta
        if meta
          media_resource.update!(meta.merge(status: status))
        else
          # TODO: should non-audio be an error or something?
          media_resource.update!(status: status)
          Rails.logger.warn("No audio meta found in result: #{JSON.generate(result)}")
        end
        episode.try(:podcast).try(:publish!)
      else
        media_resource.update!(status: status)
      end
    end
  end

  def task_options
    super.merge({
      job_type: "audio",
      source: source_url(media_resource),
      destination: destination_url(media_resource)
    }).with_indifferent_access
  end

  def source_url(media_resource)
    media_resource.original_url.sub(/\?.*$/, "")
  end

  def destination_url(media_resource)
    URI::Generic.build(
      scheme: "s3",
      host: feeder_storage_bucket,
      path: destination_path(media_resource)
    ).to_s
  end

  def destination_path(media_resource)
    URI.parse(media_resource.url).path
  end

  def episode
    media_resource.episode
  end

  def media_resource
    owner
  end
end
