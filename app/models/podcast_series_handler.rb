class PodcastSeriesHandler
  include PRXAccess

  attr_accessor :podcast, :default_feed, :series

  def self.create_from_series!(series)
    podcast = Podcast.new
    update_from_series!(podcast, series)
  end

  def self.update_from_series!(podcast, series = nil)
    series ||= get_series
    new(podcast).update_from_series!(series)
  end

  def initialize(podcast)
    self.podcast = podcast
    podcast.set_defaults
    self.default_feed = podcast.default_feed
  end

  def update_from_series!(series)
    Podcast.transaction do
      podcast.lock!
      update_from_series(series)
      podcast.save!
    end
    podcast
  end

  def update_from_series(series)
    self.series = series
    podcast.prx_uri = series.links['self'].href
    podcast.prx_account_uri = series.links['account'].href

    update_attributes
    update_images
  end

  def update_attributes
    sa = series.attributes
    updated = Time.parse(sa[:updated_at]) if sa[:updated_at]
    if updated && (podcast.source_updated_at.nil? || updated > podcast.source_updated_at)
      podcast.source_updated_at = updated
    end
    podcast.title = sa[:title]
    podcast.subtitle = sa[:short_description]
    podcast.description = sa[:description]
  end

  def update_images
    images = series.objects['prx:images'].objects['prx:items'] rescue []

    feed_image = images.find { |i| i.attributes['purpose'] == 'thumbnail' }
    default_feed.feed_image_file = feed_image.try(:links).try(:original).try(:href)

    itunes_image = images.find { |i| i.attributes['purpose'] == 'profile' }
    default_feed.itunes_image_file = itunes_image.try(:links).try(:original).try(:href)
  end

  def get_series(account = nil)
    return nil unless podcast.prx_uri
    api(account: account).tap { |a| a.href = podcast.prx_uri }.get
  end
end
