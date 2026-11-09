require "active_support/concern"

module EpisodeEnclosure
  extend ActiveSupport::Concern

  def enclosure_url(**opts)
    override? ? enclosure_override_url : enclosure_dovetail_url(**opts)
  end

  def enclosure_dovetail_url(feed: podcast&.default_feed, prefix: true, ext: nil, auth: nil, prx_jwt: nil)
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
    url_parts << enclosure_file_name(feed: feed, ext: ext)

    url = url_parts.map { |p| p.to_s.chomp("/") }.join("/")
    url = "https://#{url}" unless url.starts_with?("http")

    query = {auth: auth, _t: prx_jwt}.compact.to_query
    query.present? ? "#{url}?#{query}" : url
  end

  def enclosure_content_type(feed: podcast&.default_feed)
    if medium_passthru? || override?
      media_content_type
    elsif video?
      feed&.mime_type || "audio/mpeg"
    else
      feed&.mime_type || media_content_type
    end
  end

  def enclosure_file_name(feed: podcast&.default_feed, ext: nil)
    if medium_passthru?
      media_file_name
    else
      orig_fn = media_file_name || "audio.mp3"
      orig_ext = File.extname(orig_fn)
      orig_base = File.basename(orig_fn, orig_ext)
      if ext
        "#{orig_base}.#{ext}"
      elsif video?
        "#{orig_base}.#{feed&.file_ext || "mp3"}"
      else
        "#{orig_base}.#{feed&.file_ext || orig_ext[1..] || "mp3"}"
      end
    end
  end

  # TODO: not accurate for Feeds with audio_formats, or really any
  # Contents that need transcoding to match the first original
  def enclosure_file_size(feed: podcast&.default_feed)
    if video?
      # TODO: we don't know the size of the transcoded mp3
      1
    else
      media_file_size
    end
  end

  def enclosure_alt_url(**opts)
    enclosure_url(**opts, ext: "m3u8") if video?
  end

  def enclosure_alt_content_type
    "application/x-mpegURL" if video?
  end
end
