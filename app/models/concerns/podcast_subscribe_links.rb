require "active_support/concern"

module PodcastSubscribeLinks
  extend ActiveSupport::Concern

  def build_subscribe_links_json
    if subscribe_links.present?
      {
        version: "1.0.0",
        links: subscribe_links&.map(&:as_json)
      }.to_json
    end
  end

  def subscribe_links_path
    "#{base_published_url}/subscribelinks.json"
  end

  def copy_subscribe_links(options = {})
    opts = default_options.merge(options)
    opts[:body] = build_subscribe_links_json
    opts[:bucket] = ENV["FEEDER_STORAGE_BUCKET"]
    opts[:key] = "#{path}/subscribelinks.json"

    @put_object = s3_client.put_object(opts)
  end

  def default_options
    {
      content_type: "application/rss+xml; charset=UTF-8",
      cache_control: "max-age=60"
    }
  end

  def s3_client
    if Rails.env.test? || ENV["AWS_ACCESS_KEY_ID"].present?
      Aws::S3::Client.new(stub_responses: true)
    else
      Aws::S3::Client.new
    end
  end
end
