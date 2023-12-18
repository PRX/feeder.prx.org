require "addressable/uri"
require "addressable/template"

class EnclosureUrlBuilder
  def self.add_query_param(url, key, value)
    url = URI.parse(url)
    decoded_query = URI.decode_www_form(url.query.to_s) << [key, value]
    url.query = URI.encode_www_form(decoded_query)
    url.to_s
  end

  def self.mark_authorized(enclosure_url, feed)
    return enclosure_url unless feed.private?
    raise "Missing tokens for private feed #{feed.id}" if feed.private? && !feed.tokens.any?

    token = feed.tokens.first.token
    add_query_param(enclosure_url, "auth", token)
  end

  # Marks the url as a `noImp`
  # Used by Dovetail to skip the impression tracking
  def self.mark_no_imp(enclosure_url)
    add_query_param(enclosure_url, "noImp", "1")
  end

  def podcast_episode_url(podcast, episode, feed = nil)
    feed ||= podcast.default_feed
    prefix = feed.try(:enclosure_prefix)

    url = base_enclosure_url(podcast, episode, feed)
    enclosure_prefix_url(url, prefix)
  end

  def base_enclosure_url(podcast, episode, feed)
    template = feed.try(:enclosure_template)
    expansions = podcast_episode_expansions(podcast, episode, feed)
    enclosure_url(template, expansions)
  end

  def podcast_episode_expansions(podcast, episode, feed)
    media = episode.uncut || episode.contents.first

    original_url = media.try(:original_url) || "media"
    original = Addressable::URI.parse(original_url).to_hash
    original = original.map { |k, v| ["original_#{k}".to_sym, v] }.to_h

    base_url = media.try(:media_url) || ""
    base = Addressable::URI.parse(base_url).to_hash

    orig_fn = File.basename(original[:original_path].to_s)
    orig_ex = File.extname(original[:original_path].to_s)
    fn = File.basename(base[:path].to_s)
    ex = File.extname(base[:path].to_s)

    # extensions matter for audio, so default to .mp3 if not wav or flac
    if media.try(:audio?) && !%w[.wav .flac].include?(ex)
      ex = ".mp3"
    end

    {
      original_filename: orig_fn,
      original_extension: orig_ex,
      original_basename: File.basename(orig_fn, orig_ex),
      filename: fn,
      extension: ex,
      basename: File.basename(fn, ex),
      podcast_id: podcast.try(:id),
      guid: episode.guid,
      slug: podcast.try(:id),
      feed_slug: feed.try(:slug),
      feed_extension: feed_extension(feed) || ex
    }.merge(original).merge(base)
  end

  def feed_extension(feed)
    format = (feed.try(:audio_format) || {})[:f]
    format ? ".#{format}" : nil
  end

  def enclosure_url(template, expansions)
    enclosure_template_url(template, expansions)
  end

  def enclosure_template_url(template, expansions)
    template = Addressable::Template.new(template)
    template.expand(expansions).to_str
  end

  def enclosure_prefix_url(u, prefix)
    return u if prefix.blank?

    pre = Addressable::URI.parse(prefix)
    orig = Addressable::URI.parse(u)
    orig.path = File.join(pre.path, orig.host, orig.path)
    orig.scheme = pre.scheme
    orig.host = pre.host
    orig.to_s
  end
end
