class FeedDecorator

  attr_accessor :feed

  def initialize(f)
    @feed = f
  end

  def overrides
    feed.overrides || {}
  end

  def podcast
    feed.podcast
  end

  def feed_file
    "feed-rss-#{feed.name || feed.id}.xml"
  end

  def feed_episodes
    eps = podcast.feed_episodes
    feed_max = (overrides[:display_episodes_count] || podcast.display_episodes_count).to_i
    feed_max > 0 ? eps[0, feed_max] : eps
  end

  def method_missing(method, *args, &block)
    if feed.overridden?(method)
      overrides[method]
    elsif podcast && podcast.respond_to?(method)
      podcast.send(method, *args, &block)
    else
      super
    end
  end
end
