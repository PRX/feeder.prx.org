class Tasks::PublishFeedTask < ::Task

  include Rails.application.routes.url_helpers

  def start!
    self.options = {
      job_type: 'file',
      source: source_url,
      destination: destination_url
    }.with_indifferent_access
    job = fixer_copy_file(options)
    self.job_id = job[:job][:id]
    save!
  end

  def source_url(podcast = owner)
    podcast_url(podcast, host: ENV['FEEDER_APP_HOST'])
  end

  def destination_url(podcast = owner)
    key = File.join(podcast.path, 'feed-rss.xml')
    "s3://#{feeder_storage_bucket}/#{key}?x-fixer-public=true"
  end

  def task_status_changed(fixer_task)
    # purge the cdn cache
    # (send out a feed updated event?)
  end

  def podcast
    owner
  end
end
