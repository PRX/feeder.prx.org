require 'builder'

class PublishFeedJob < ApplicationJob

  queue_as :feeder_default

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss

  def perform(podcast)
    setup_data(podcast)
    @rss = generate_rss_xml
    save_podcast_file(@rss)
  end

  def setup_data(podcast)
    @podcast = podcast
    @episodes = @podcast.feed_episodes
  end

  def generate_rss_xml
    xml = Builder::XmlMarkup.new(indent: 2)
    instance_eval rss_template
    xml.target!
  end

  def rss_template
    p = File.join(Rails.root, 'app', 'views', 'podcasts', 'show.rss.builder')
    File.read(p)
  end

  def save_podcast_file(rss, options = {})
    default_options = {
      acl: 'public-read',
      content_type: 'application/rss+xml; charset=UTF-8',
      cache_control: 'max-age=60'
    }

    opts = default_options.merge(options)
    opts[:body] = rss

    obj = connection.bucket(feeder_storage_bucket).object(key)
    obj.put(opts)
  end

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET']
  end

  def key(podcast = @podcast)
    "#{podcast.path}/feed-rss.xml"
  end

  def connection
    Aws::S3::Resource.new(
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      region: ENV['AWS_REGION']
    )
  end
end
