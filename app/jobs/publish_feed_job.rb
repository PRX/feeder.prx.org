require 'builder'

class PublishFeedJob < ApplicationJob

  queue_as :feeder_default

  include PodcastsHelper

  attr_accessor :podcast, :episodes, :rss, :put_object, :copy_object

  def perform(podcast)
    setup_data(podcast)
    @rss = generate_rss_xml
    save_podcast_file(@rss)
    if podcast.default_feed.file_name != Feed::DEFAULT_FILE_NAME
      copy_podcast_file_alias
    end
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

  # TODO: use the default_feed.file_name
  def key(podcast = @podcast)
    "#{podcast.path}/feed-rss.xml"
  end

  # TODO: no need for copy aliases when the feed has the file_name
  def alias_key(podcast = @podcast)
    "#{podcast.path}/#{podcast.default_feed.file_name}"
  end

  def default_options
    {
      content_type: 'application/rss+xml; charset=UTF-8',
      cache_control: 'max-age=60'
    }
  end

  def client
    if Rails.env.test? || ENV['AWS_ACCESS_KEY_ID'].present?
      s3 = Aws::S3::Client.new(
        credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY']),
        region: ENV['AWS_REGION']
      )
    else
      s3 = Aws::S3::Client.new
    end
  end
end
