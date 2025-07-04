require "active_support/concern"

module PublishingNotify
  extend ActiveSupport::Concern

  def notify_rss_published(podcast, feed)
    notify_podping(feed)
  rescue => e
    Rails.logger.error("notify_rss_published error", {podcast: podcast.id, feed: feed.id, error: e})
  end

  def notify_podping(feed)
    return unless podping_enabled?(feed)

    podping_host = ENV["PODPING_HOST"] || "podping.cloud"
    url = "https://#{podping_host}/"
    headers = podping_headers
    params = {url: feed.published_public_url}

    connection = Faraday.new(url: url, headers: headers, params: params) do |builder|
      builder.response :raise_error
      builder.response :logger, Rails.logger
    end

    connection.get
  end

  def podping_enabled?(feed)
    ENV["PODPING_AUTH_TOKEN"].present? && feed.public?
  end

  def podping_headers
    {
      "User-Agent" => "PRX",
      "Authorization" => ENV["PODPING_AUTH_TOKEN"]
    }
  end
end
