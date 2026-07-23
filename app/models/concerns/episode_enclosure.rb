require "active_support/concern"

module EpisodeEnclosure
  extend ActiveSupport::Concern

  def enclosure_url(**opts)
    override? ? enclosure_override_url : enclosure_dovetail_url(**opts)
  end

  def enclosure_dovetail_url(feed: podcast&.default_feed, prefix: true, auth: nil, prx_jwt: nil)
    auth =
      if feed&.public?
        nil
      elsif auth == true
        feed&.tokens&.first&.token
      else
        auth.presence
      end

    url_parts = []
    url_parts << feed.enclosure_prefix if feed&.enclosure_prefix.present? && prefix
    url_parts << (ENV["DOVETAIL_HOST"] || "dovetail.prxu.org")
    url_parts << (podcast_id || "podcast")
    url_parts << feed.slug if feed&.slug.present?
    url_parts << guid
    url_parts << enclosure_file_name(feed: feed)

    url = url_parts.map { |p| p.to_s.chomp("/") }.join("/")
    url = "https://#{url}" unless url.starts_with?("http")

    query = {auth: auth, _t: prx_jwt}.compact.to_query
    query.present? ? "#{url}?#{query}" : url
  end

  def enclosure_content_type(feed: podcast&.default_feed)
    if override? || medium_video?
      media_content_type
    else
      feed&.mime_type || media_content_type
    end
  end

  def enclosure_file_name(feed: podcast&.default_feed)
    if medium_video?
      media_file_name
    else
      orig_fn = media_file_name || "audio.mp3"
      orig_ext = File.extname(orig_fn)
      orig_base = File.basename(orig_fn, orig_ext)
      ext = feed&.file_ext || orig_ext[1..] || "mp3"
      "#{orig_base}.#{ext}"
    end
  end

  # TODO: not accurate for Feeds with audio_formats, or really any
  # Contents that need transcoding to match the first original
  def enclosure_file_size(feed: podcast&.default_feed)
    media_file_size
  end
end
