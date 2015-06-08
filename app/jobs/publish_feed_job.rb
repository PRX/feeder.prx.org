require 'builder'

class PublishFeedJob < ActiveJob::Base

  queue_as :feeder_default

  attr_accessor :podcast, :episodes

  def perform(podcast)
    setup_data(podcast)
    @rss = generate_rss_xml
    save_podcast_file(@rss)
  end

  def setup_data(podcast)
    @podcast = podcast
    episodes = @podcast.episodes.order('created_at desc')
    @episodes = episodes.map { |e| EpisodeBuilder.from_prx_story(e) }
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
    default_options = { public: true, content_type: 'text/xml; charset=UTF-8' }
    opts = default_options.merge(options)
    opts[:body] = rss
    opts[:key] = key

    directory = connection.directories.create(key: bucket, public: false)
    s3_file = directory.files.create(opts)
  end

  def key(podcast = @podcast)
    File.join(podcast.path, 'feed-rss.xml')
  end

  def bucket
    ENV['FEEDER_STORAGE_BUCKET'] ||
      (Rails.env.production? ? '' : (Rails.env + '-')) + 'prx-feeds'
  end

  def connection
    options = {
      provider: 'AWS',
      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      aws_secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
      region:  ENV['AWS_REGION']
    }
    Fog::Storage.new(options)
  end
end
