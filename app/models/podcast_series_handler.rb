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
  end

  def update_images
    images = series.objects['prx:images'].objects['prx:items'] rescue []
    { feed: 'thumbnail', itunes: 'profile' }.each do |type, purpose|
      if image = images.detect { |i| i.attributes['purpose'] == purpose }
        image_url = image.links['original'].href
        if !podcast.find_existing_image(type, image_url)
          podcast.send("#{type}_images").build(original_url: image_url)
        end
      else
        podcast.send("#{type}_images").destroy_all
      end
    end
  end

  def get_series(account = nil)
    return nil unless podcast.prx_uri
    api(account: account).tap { |a| a.href = podcast.prx_uri }.get
  end
end
