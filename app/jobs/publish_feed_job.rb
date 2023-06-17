require "builder"
require "s3_access"

# Publish the feed:
#  Sync to to Apple
#  Saves the RSS feed to s3
class PublishFeedJob < ApplicationJob
  queue_as :feeder_default

  include PodcastsHelper
  include S3Access

  attr_accessor :podcast, :episodes, :rss, :put_object

  def perform(podcast)
    podcast.feeds.each { |feed| publish_feed(podcast, feed) }
  end

  def publish_feed(podcast, feed)
    publish_apple(feed)
    publish_rss(podcast, feed)
  end

  def publish_apple(feed)
    feed.apple_configs.map do |config|
      if feed.publish_to_apple?(config)
        PublishAppleJob.perform_later(config)
      end
    end
  end

  def publish_rss(podcast, feed)
    save_file(podcast, feed)
  end

  def save_file(podcast, feed, options = {})
    rss = FeedBuilder.new(podcast, feed).to_feed_xml
    opts = default_options.merge(options)
    @put_object = s3_save_file(rss, key(podcast, feed), opts)
  end

  def key(podcast, feed)
    "#{podcast.path}/#{feed.published_path}"
  end

  def default_options
    {
      content_type: "application/rss+xml; charset=UTF-8",
      cache_control: "max-age=60"
    }
  end
end
