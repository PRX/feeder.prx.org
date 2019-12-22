require 'feed_builder'
require 'feed_decorator'

class PublishFeedJob < ApplicationJob
  queue_as :feeder_default

  include PodcastsHelper

  def perform(podcast)
    rss = save_file(podcast)
    podcast.feeds.each { |f| save_file(FeedDecorator.new(f)) }
    rss
  end

  def save_file(podcast, options = {})
    rss = FeedBuilder.new(podcast).to_feed_xml

    default_options = {
      acl: 'public-read',
      content_type: 'application/rss+xml; charset=UTF-8',
      cache_control: 'max-age=60'
    }

    opts = default_options.merge(options)
    opts[:body] = rss

    obj = connection.bucket(feeder_storage_bucket).object(key(podcast))
    obj.put(opts)
    rss
  end

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET']
  end

  def key(podcast)
    "#{podcast.path}/#{podcast.feed_file}"
  end

  def connection
    Aws::S3::Resource.new(
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      region: ENV['AWS_REGION']
    )
  end
end
