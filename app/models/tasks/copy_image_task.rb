class Tasks::CopyImageTask < ::Task
  def start!
    self.options = task_options
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]

    # TODO Only used in prototyping
    send_rexif_job

    save!
  end

  # TODO Only used in prototyping
  def send_rexif_job
    return if !image_resource.original_url
    return if !ENV['REXIF_CALLBACK_SQS_QUEUE']

    if image_resource.original_url.match(/^s3:/)
      parts = image_resource.original_url.gsub(/^s3:\/\//, '').split('/', 2)
      source = {
        Mode: 'AWS/S3',
        BucketName: parts[0],
        ObjectKey: parts[1]
      }
    elsif image_resource.original_url.match(/^https:/)
      source = {
        Mode: 'HTTP',
        URL: image_resource.original_url
      }
    else
      return
    end

    if ENV['REXIF_JOB_EXECUTION_SNS_TOPIC']
      sns = Aws::SNS::Client.new
      sns.publish({
        topic_arn: ENV['REXIF_JOB_EXECUTION_SNS_TOPIC'],
        message: JSON.dump({
          Job: {
            Id: self.job_id,
            Source: source,
            Copy: {
              Destinations: [
                Mode: 'AWS/S3',
                BucketName: feeder_storage_bucket,
                ObjectKey: "#{image_path(image_resource)}_rexif".gsub(/^\//, '')
              ]
            },
            Callbacks: [
              {
                Type: 'AWS/SQS',
                Queue: ENV['REXIF_CALLBACK_SQS_QUEUE']
              }
            ]
          }
        })
      })
    end
  end

  def task_status_changed(fixer_task, new_status)
    return if !image_resource
    image_resource.update_attribute(:status, new_status)

    if fixer_task && new_status == 'complete'
      image_resource.update_from_fixer(fixer_task)
      podcast.publish!
    end
  end

  def task_options
    {
      job_type: 'file',
      source: image_resource.original_url,
      destination: destination_url(image_resource)
    }.with_indifferent_access
  end

  def destination_url(image_resource)
    URI::Generic.build(
      scheme: 's3',
      host: feeder_storage_bucket,
      path: image_path(image_resource),
      query: fixer_query
    ).to_s
  end

  def image_path(image_resource)
    if !image_resource
      logger.info("in CopyImageTask#image_path and image_resource is nil. self is #{self.inspect}")
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
