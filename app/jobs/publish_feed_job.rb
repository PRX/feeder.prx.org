require "builder"

class PublishFeedJob < ApplicationJob
  queue_as :feeder_publishing

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

  def perform(podcast)
    PublishingPipelineState.start!(podcast)
    podcast.feeds.each { |feed| publish_feed(podcast, feed) }
    PublishingPipelineState.complete!(podcast)
  rescue => e
    PublishingPipelineState.error!(podcast)
    raise e
  ensure
    PublishingPipelineState.settle_remaining!(podcast)
  end

  def publish_feed(podcast, feed)
    publish_apple(feed)
    publish_rss(podcast, feed)
  end

  def publish_apple(feed)
    feed.apple_configs.map do |config|
      if feed.publish_to_apple?(config)
        res = PublishAppleJob.perform_now(config)
        PublishingPipelineState.publish_apple!(feed.podcast)
        res
      end
    rescue => e
      NewRelic::Agent.notice_error(e)
      res = PublishingPipelineState.error_apple!(feed.podcast)
      raise e if config.sync_blocks_rss?
      res
    end
  end

  def publish_rss(podcast, feed)
    res = save_file(podcast, feed)
    PublishingPipelineState.publish_rss!(podcast)
    res
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
