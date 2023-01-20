require "builder"

class FeedBuilder
  include PodcastsHelper

  attr_accessor :podcast, :feed, :episodes

  def initialize(podcast, feed = nil)
    @podcast = podcast
    @feed = feed || podcast.default_feed
    @episodes = @feed.feed_episodes
    @feed_image = @feed.feed_image || @podcast.feed_image
    @itunes_image = @feed.itunes_image || @podcast.itunes_image
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
