require 'addressable/uri'
require 'addressable/template'

class EnclosureUrlBuilder

  def podcast_episode_url(podcast, episode)
    template = podcast.try(:enclosure_template)
    prefix = podcast.try(:enclosure_prefix)
    if template.blank?
      enclosure_prefix_url(episode.media_url, prefix)
    else
      expansions = podcast_episode_expansions(podcast, episode)
      enclosure_url(template, expansions, prefix)
    end
  end

  def podcast_episode_expansions(podcast, episode)
    media = episode.first_media_resource

    original_url = media.try(:original_url) || ''
    original = Addressable::URI.parse(original_url).to_hash
    original = Hash[original.map { |k,v| ["original_#{k}".to_sym, v] }]

    base_url = media.try(:media_url) || ''
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
      slug: podcast.path,
      guid: episode.guid
    }.merge(original).merge(base)
  end

  def enclosure_url(template, expansions, prefix=nil)
    url = enclosure_template_url(template, expansions)
    url = enclosure_prefix_url(url, prefix)
    url
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
