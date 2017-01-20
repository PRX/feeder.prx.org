require 'prx_access'

class SeriesUpdateJob < ActiveJob::Base
  include Announce::Subscriber
  include PRXAccess

  queue_as :feeder_default

  subscribe_to :series, [:create, :update, :delete]

  attr_accessor :body, :podcast, :series

  def perform(*args)
    ActiveRecord::Base.connection_pool.with_connection do
      super
    end
  end

  def receive_series_update(data)
    load_resources(data)
    podcast ? update_podcast : create_podcast
    podcast.publish! if podcast
  end

  alias receive_series_create receive_series_update

  def receive_series_delete(data)
    load_resources(data)
    podcast.destroy if podcast
  end

  def load_resources(data)
    self.body = data.is_a?(String) ? JSON.parse(data) : data
    self.series = api_resource(body.with_indifferent_access)
    self.podcast = Podcast.by_prx_series(series)
  end

  def update_podcast
    series_updated = Time.parse(series.attributes[:updated_at]) if series.attributes[:updated_at]
    if podcast.source_updated_at && series_updated && series_updated < podcast.source_updated_at
      logger.info("Not updating podcast: #{podcast.id} as #{series_updated} > #{podcast.source_updated_at}")
    else
      podcast.restore if podcast.deleted?
      self.podcast = PodcastSeriesHandler.update_from_series!(podcast, series)
    end
  end

  def create_podcast
    return unless series && series.try(:series)
    self.podcast = PodcastSeriesHandler.create_from_series!(series)
  end
end
