class SeriesUpdateWorker < ApplicationWorker
  shoryuken_options queue: announce_queues(:series, [:create, :update, :delete]),
                    auto_delete: true

  attr_accessor :body, :podcast, :series

  def perform(_sqs_msg, event)
    announce_perform(event)
  end

  def receive_series_update(data)
    load_resources(data)
    if podcast
      update_podcast
      podcast.copy_media
      podcast.publish!
    end
  end

  alias receive_series_create receive_series_update

  def receive_series_delete(data)
    load_resources(data)
    podcast&.destroy
  end

  def load_resources(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
    self.series = api_resource(body.with_indifferent_access)
    self.podcast = Podcast.by_prx_series(series)
  end

  def update_podcast
    series_updated = Time.parse(series.attributes[:updated_at]) if series.attributes[:updated_at]
    if podcast.source_updated_at && series_updated && series_updated < podcast.source_updated_at
      logger.info("Not updating podcast: #{podcast.id} as #{series_updated} < #{podcast.source_updated_at}")
    else
      self.podcast = PodcastSeriesHandler.update_from_series!(podcast, series)
    end
  end
end
