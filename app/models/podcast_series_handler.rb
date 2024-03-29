class PodcastSeriesHandler
  include PrxAccess

  attr_accessor :podcast, :series

  def self.create_from_series!(series)
    podcast = Podcast.new
    update_from_series!(podcast, series)
  end

  def self.update_from_series!(podcast, series = nil)
    handler = new(podcast)
    handler.update_from_series!(series || handler.get_series)
  end

  def initialize(podcast)
    self.podcast = podcast
    podcast.set_defaults
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
    podcast.prx_uri = series.links["self"].href
    podcast.prx_account_uri = series.links["account"].href

    update_series_attributes
    update_images
  end

  def update_series_attributes
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
    cms_images = begin
      (series.objects["prx:images"] || series.links["prx:images"]).objects["prx:items"]
    rescue
      []
    end
    purposes = {feed_image: "thumbnail", itunes_image: "profile"}

    purposes.each do |name, purpose|
      cms_image = cms_images.find { |i| i.attributes["purpose"] == purpose }
      cms_href = begin
        cms_image.links["original"].href
      rescue
        nil
      end

      podcast.default_feed.public_send("#{name}=", cms_href)

      if cms_href.present?
        podcast.default_feed.public_send(name).caption = cms_image.attributes["caption"]
        podcast.default_feed.public_send(name).credit = cms_image.attributes["credit"]
      end
    end
  end

  def get_series(account = nil)
    return nil unless podcast.prx_uri
    api(account: account).tap { |a| a.href = podcast.prx_uri }.get
  end
end
