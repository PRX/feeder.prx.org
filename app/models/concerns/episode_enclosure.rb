require "active_support/concern"

module EpisodeEnclosure
  extend ActiveSupport::Concern

  def enclosure_url(feed: nil, prefix: true, auth: nil, prx_jwt: nil)
    feed ||= podcast&.default_feed

    # optionally include auth for private feeds
    auth =
      if feed.public?
        nil
      elsif auth == true
        feed.tokens&.first&.token
      else
        auth.presence
      end

    url_parts = []
    url_parts << feed.enclosure_prefix if feed&.enclosure_prefix.present? && prefix
    url_parts << (ENV["DOVETAIL_HOST"] || "dovetail")
    url_parts << (podcast_id || "podcast")
    url_parts << feed.slug if feed&.slug.present?
    url_parts << guid
    url_parts << (media_file_name(feed).presence || "file.mp3")

    url = url_parts.map { |p| p.to_s.chomp("/") }.join("/")
    url = "https://#{url}" unless url.starts_with?("http")

    query = {auth: auth, _t: prx_jwt}.compact.to_query
    query.present? ? "#{url}?#{query}" : url
  end

  def enclosure_filename(feed: nil)
    uri = URI.parse(enclosure_url(feed))
    File.basename(uri.path)
  end
end
