require "addressable/uri"
require "addressable/template"

class EnclosureUrlBuilder
  def podcast_episode_url(podcast, episode, feed = nil)
    feed ||= podcast.default_feed
    template = feed.try(:enclosure_template)
    prefix = feed.try(:enclosure_prefix)
    expansions = podcast_episode_expansions(podcast, episode, feed)
    enclosure_url(template, expansions, prefix)
  end

  def podcast_episode_expansions(podcast, episode, feed)
    media = episode.first_media_resource

    original_url = media.try(:original_url) || ""
    original = Addressable::URI.parse(original_url).to_hash
    original = original.map { |k, v| ["original_#{k}".to_sym, v] }.to_h

    base_url = media.try(:media_url) || ""
    base = Addressable::URI.parse(base_url).to_hash

    orig_fn = File.basename(original[:original_path].to_s)
    orig_ex = File.extname(original[:original_path].to_s)
    fn = File.basename(base[:path].to_s)
    ex = File.extname(base[:path].to_s)

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

  def enclosure_url(template, expansions, prefix = nil)
    url = enclosure_template_url(template, expansions)
    enclosure_prefix_url(url, prefix)
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
