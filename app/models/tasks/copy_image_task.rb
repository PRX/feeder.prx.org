class Tasks::CopyImageTask < ::Task
  before_save do
    if image_resource && status_changed?
      image_resource.update!(status: status)
      if complete?
        image_resource.update!(url: image_resource.published_url)
        podcast.try(:publish!)
      end
    end
  end

  def task_options
    super.merge({
      job_type: "file",
      source: image_resource.original_url,
      destination: destination_url(image_resource)
    }).with_indifferent_access
  end

  def destination_url(image_resource)
    URI::Generic.build(
      scheme: "s3",
      host: feeder_storage_bucket,
      path: image_path(image_resource)
    ).to_s
  end

  def image_path(image_resource)
    if !image_resource
      logger.info("in CopyImageTask#image_path and image_resource is nil. self is #{inspect}")
    end
    URI.parse(image_resource.published_url).path
  end

  def podcast
    image_resource.try(:episode).try(:podcast) || image_resource.try(:podcast)
  end

  def image_resource
    owner
  end
end
