class Tasks::CopyImageTask < ::Task
  before_save do
    if image_resource && status_changed?
      if complete?
        meta = porter_callback_image_meta
        if meta
          update_image!(meta.merge(url: image_resource.published_url))
          podcast.try(:publish!)
        else
          update_image!
          Rails.logger.warn("No image meta found in result: #{JSON.generate(result)}")
        end
      else
        update_image!
      end
    end
  end

  def task_options
    super.merge({
      job_type: "image",
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

  private

  def update_image!(attrs = {})
    image_resource.update!(attrs.merge(status: status))
  rescue ActiveRecord::RecordInvalid
    # TODO: handle/display async validation issues
    image_resource.restore_attributes
    image_resource.update!(status: "error")
  end
end
