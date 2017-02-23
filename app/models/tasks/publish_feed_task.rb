require 'weblog_updater'

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
    podcast_url(podcast, host: ENV['FEEDER_HOST'])
  end

  def destination_url(podcast = owner)
    query = URI.encode_www_form(
      'x-fixer-public' => 'true',
      'x-fixer-Content-Type' => 'application/rss+xml; charset=UTF-8'
    )
    URI::Generic.build(
      scheme: 's3',
      host: feeder_storage_bucket,
      path: feed_path,
      query: query
    ).to_s
  end

  def task_status_changed(fixer_task, new_status)
    # purge the cdn cache
    HighwindsAPI::Content.purge_url(podcast.published_url, false)

    # send out a feed updated event?
    if podcast.feedburner_url
      WeblogUpdater.ping(feed_url: podcast.feedburner_url)
    end
  end

  def feed_path(podcast = owner)
    URI.parse(podcast.published_url).path
  end

  def podcast
    owner
  end
end
