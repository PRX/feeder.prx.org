require "builder"

class FeedBuilder
  include PodcastsHelper

  attr_accessor :podcast, :feed, :episodes

  def initialize(podcast, feed = nil)
    @podcast = podcast
    @feed = feed || podcast.default_feed
    @episodes = @feed.feed_episodes
    @feed_image = @feed.ready_feed_image || @podcast.ready_feed_image
    @itunes_image = @feed.ready_itunes_image || @podcast.ready_itunes_image
    @itunes_categories = @feed.itunes_categories.present? ? @feed.itunes_categories : podcast.default_feed.itunes_categories
  end

  def to_feed_xml
    xml = Builder::XmlMarkup.new(indent: 2)
    instance_eval rss_template
    xml.target!
  end

  def rss_template
    p = File.join(Rails.root, "app", "views", "podcasts", "show.rss.builder")
    File.read(p)
  end
end
