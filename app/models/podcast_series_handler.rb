require 'podcast'

class PodcastSeriesHandler
  include PRXAccess

  attr_accessor :podcast, :series

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
    podcast.summary = sa[:description]
  end

  def update_images
    images = series.objects['prx:images'].objects['prx:items'] rescue []
    { feed: 'thumbnail', itunes: 'profile' }.each do |type, purpose|
      if image = images.detect { |i| i.attributes['purpose'] == purpose }
        save_image(podcast, type, cms_url(image.links['original'].href))
      elsif i = podcast.send("#{type}_image")
        i.destroy
      end
    end
  end

  def save_image(podcast, type, url)
    if i = podcast.send("#{type}_image")
      i.update_attributes!(url: url)
    else
      podcast.send("build_#{type}_image", url: url)
    end
  end

  def get_series(account = nil)
    return nil unless podcast.prx_uri
    api(account: account).tap { |a| a.href = podcast.prx_uri }.get
  end

  def cms_url(url)
    if url =~ /^http/
      url
    else
      path_to_url(ENV['CMS_HOST'], url)
    end
  end

  def path_to_url(host, path)
    if host =~ /\.org/ # TODO: should .tech's be here too?
      URI::HTTPS.build(host: host, path: path).to_s
    else
      URI::HTTP.build(host: host, path: path).to_s
    end
  end
end
