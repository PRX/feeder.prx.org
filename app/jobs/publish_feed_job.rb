require 'builder'

class PublishFeedJob < ApplicationJob

  queue_as :feeder_default

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

  def perform(podcast)
    setup_data(podcast)
    @rss = generate_rss_xml
    save_podcast_file(@rss)
    copy_podcast_file_alias if podcast.feed_rss_alias.present?
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
    opts = default_options.merge(options)
    opts[:body] = rss
    opts[:bucket] = feeder_storage_bucket
    opts[:key] = key
    @put_object = client.put_object(opts)
  end

  def copy_podcast_file_alias(options = {})
    opts = default_options.merge(options)
    opts[:bucket] = feeder_storage_bucket
    opts[:copy_source] = "#{feeder_storage_bucket}/#{key}"
    opts[:key] = alias_key
    @copy_object = client.copy_object(opts)
  end

  def feeder_storage_bucket
    ENV['FEEDER_STORAGE_BUCKET']
  end

  def key(podcast = @podcast)
    "#{podcast.path}/feed-rss.xml"
  end

  def alias_key(podcast = @podcast)
    "#{podcast.path}/#{podcast.feed_rss_alias}"
  end

  def default_options
    {
      acl: 'public-read',
      content_type: 'application/rss+xml; charset=UTF-8',
      cache_control: 'max-age=60'
    }
  end

  def client
    s3 = Aws::S3::Client.new(
      credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
      region: ENV['AWS_REGION']
    )
  end
end
