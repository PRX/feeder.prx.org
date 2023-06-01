require "builder"

class PublishFeedJob < ApplicationJob
  queue_as :feeder_default

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

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
        if config.sync_blocks_rss?
          PublishAppleJob.perform_now(config)
        else
          PublishAppleJob.perform_later(config)
        end
      end
    end
  end

  def publish_rss(podcast, feed)
    save_file(podcast, feed)
  end

  def save_file(podcast, feed, options = {})
    rss = FeedBuilder.new(podcast, feed).to_feed_xml
    opts = default_options.merge(options)
    opts[:body] = rss
    opts[:bucket] = feeder_storage_bucket
    opts[:key] = key(podcast, feed)
    @put_object = client.put_object(opts)
  end

  def feeder_storage_bucket
    ENV["FEEDER_STORAGE_BUCKET"]
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

  def client
    if Rails.env.test? || ENV["AWS_ACCESS_KEY_ID"].present?
      Aws::S3::Client.new(
        credentials: Aws::Credentials.new(ENV["AWS_ACCESS_KEY_ID"], ENV["AWS_SECRET_ACCESS_KEY"]),
        region: ENV["AWS_REGION"]
      )
    else
      Aws::S3::Client.new
    end
  end
end
