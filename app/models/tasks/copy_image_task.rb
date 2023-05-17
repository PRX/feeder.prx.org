class Tasks::CopyImageTask < ::Task
  before_save do
    if image_resource && status_changed?
      image_resource.status = status

      if complete?
        image_resource.assign_attributes(porter_callback_image_meta)
        image_resource.status = "invalid" if image_resource.invalid?
      end

      image_resource.save!
      podcast.try(:publish!) if image_resource.status_complete?
    end
  end

  def task_options
    super.merge({
      job_type: "image",
      source: image_resource.href,
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
