class Tasks::CopyMediaTask < ::Task

  def start!
    self.options = task_options
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]

    # send_rexif_job

    save!
  end

  def send_rexif_job
    if ENV['REXIF_JOB_EXECUTION_SNS_TOPIC']
      sns = Aws::SNS::Client.new
      sns.publish({
        topic_arn: ENV['REXIF_JOB_EXECUTION_SNS_TOPIC'],
        message: JSON.dump({
          Job: {
            Id: self.job_id,
            Source: {
              URI: source_url(media_resource)
            },
            Copy: {
              Destinations: [
                Mode: 'S3',
                BucketName: feeder_storage_bucket,
                ObjectKey: destination_path(media_resource)
              ]
            }
          }
        })
      })
    end
  end

  # callback - example result info:
  # {
  #   :size=>774059,
  #   :content_type=>"audio/mpeg",
  #   :format=>"mp3",
  #   :channel_mode=>"Mono",
  #   :channels=>1,
  #   :bit_rate=>128,
  #   :length=>48.352653,
  #   :sample_rate=>44100
  # }
  def task_status_changed(fixer_task, new_status)
    return if !media_resource
    media_resource.update_attribute(:status, new_status)

    if fixer_task && new_status == 'complete'
      media_resource.update_from_fixer(fixer_task)
      episode.podcast.publish!
    end
  end

  def task_options
    {
      job_type: 'audio',
      source: source_url(media_resource),
      destination: destination_url(media_resource)
    }.with_indifferent_access
  end

  def source_url(media_resource)
    media_resource.original_url.sub(/\?.*$/, '')
  end

  def destination_url(media_resource)
    URI::Generic.build(
      scheme: 's3',
      host: feeder_storage_bucket,
      path: destination_path(media_resource),
      query: fixer_query
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
