require "active_support/concern"

module PublishingNotify
  extend ActiveSupport::Concern

  def notify_rss_published(podcast, feed)
    [:notify_podping, :notify_websub].each do |notify|
      send(notify, feed)
    rescue => e
      Rails.logger.error("notify_rss_published error", {podcast: podcast.id, feed: feed.id, notify: notify, error: e})
    end
  end

  def notify_podping(feed)
    return unless podping_enabled?(feed)

    podping_host = ENV["PODPING_HOST"] || "podping.cloud"
    url = "https://#{podping_host}/"
    headers = podping_headers
    params = {url: feed.url}

    connection = Faraday.new(url: url, headers: headers, params: params) do |builder|
      builder.response :raise_error
      builder.response :logger, Rails.logger
    end

    connection.get
  end

  def notify_enabled?(feed)
    feed&.public? && feed&.url.present?
  end

  def podping_enabled?(feed)
    ENV["PODPING_AUTH_TOKEN"].present? && notify_enabled?(feed)
  end

  def podping_headers
    {
      "User-Agent" => "PRX",
      "Authorization" => ENV["PODPING_AUTH_TOKEN"]
    }
  end

  def notify_websub(feed)
    return unless websub_enabled?(feed)

    connection = Faraday.new(url: websub_hub_url, headers: {"User-Agent" => "PRX"}) do |builder|
      builder.request :url_encoded
      builder.response :raise_error
      builder.response :logger, Rails.logger
    end

    connection.post("", {"hub.mode" => "publish", "hub.url" => feed.url})
  end

  def websub_enabled?(feed)
    websub_hub_url.present? && notify_enabled?(feed)
  end

  def websub_hub_url
    ENV.fetch("WEBSUB_HUB_URL", "https://pubsubhubbub.appspot.com/").presence
  end
end
