require 'builder'

class FeedBuilder
  include PodcastsHelper

  attr_accessor :podcast, :episodes

  def initialize(podcast)
    @podcast = podcast
    @episodes = @podcast.feed_episodes
  end

  def to_feed_xml
    xml = Builder::XmlMarkup.new(indent: 2)
    instance_eval rss_template
    xml.target!
  end

  def rss_template
    p = File.join(Rails.root, 'app', 'views', 'podcasts', 'show.rss.builder')
    File.read(p)
  end
end
