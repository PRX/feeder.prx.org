class Tasks::CopyImageTask < ::Task
  def start!
    self.options = task_options
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]
    save!
  end

  def task_status_changed(fixer_task, new_status)
    return if !image_resource
    image_resource.update_attribute(:status, new_status)

    if fixer_task && new_status == 'complete'
      image_resource.update_from_fixer(fixer_task)
      HighwindsAPI::Content.purge_url(image_resource.url, false)
      podcast.publish!
    end
  end

  def task_options
    {
      job_type: 'audio',
      source: image_resource.original_url,
      destination: destination_url(image_resource)
    }.with_indifferent_access
  end

  def destination_url(image_resource)
    URI::Generic.build(
      scheme: 's3',
      host: feeder_storage_bucket,
      path: image_path(image_resource),
      query: "x-fixer-public=true"
    ).to_s
  end

  def image_path(image_resource)
    URI.parse(image_resource.published_url).path
  end

  def podcast
    image_resource.try(:episode).try(:podcast) || image_resource.try(:podcast)
  end

  def image_resource
    owner
  end
end
