require 'addressable/uri'
require 'addressable/template'
require 'prx_access'

class EpisodeBuilder
  include PRXAccess

  def self.from_prx_story(opts = {})
    new(opts).from_prx_story
  end

  def initialize(e)
    @ep = e
    @prx_uri = e.prx_uri
    @overrides = (e.overrides || HashWithIndifferentAccess.new)
  end

  def from_prx_story
    info = HashWithIndifferentAccess.new(
      guid: @ep.item_guid,
      audio: audio_file,
      image_url: nil,
      created: @ep.created_at,
      modified: @ep.updated_at
    )

    if @story = get_story
      sa = @story.attributes
      story_info = HashWithIndifferentAccess.new(
        link: link(@story),
        title: sa[:title],
        subtitle: Sanitize.fragment(sa[:shortDescription] || '').strip,
        description: Sanitize.fragment(sa[:description] || '').strip,
        summary: sa[:description],
        content: sa[:description],
        explicit: sa[:contentAdvisory] ? 'yes' : 'no',
        keywords: sa[:tags],
        categories: sa[:tags],
        published: (Time.parse(sa[:publishedAt]) if sa[:publishedAt])
      )
      info.merge!(story_info)
    end

    info.merge!(@overrides) if @overrides

    info
  end

  def audio_file(episode = @ep)
    episode.enclosure_info.tap do |info|
      info[:url] = rewrite_audio_url(info[:url]) if info
    end
  end

  def rewrite_audio_url(url)
    et = @ep.enclosure_template
    return url if et.blank?

    url_info = Addressable::URI.parse(url).to_hash
    url_info.merge!(
      extension: url_info[:path].split('.').pop,
      slug: @ep.podcast_slug,
      guid: @ep.guid
    )
    template = Addressable::Template.new(et)
    template.expand(url_info).to_str
  end

  def get_story(account = nil)
    return nil unless @prx_uri
    api(account: account).tap { |a| a.href = @prx_uri }.get
  end

  def link(story = @story)
    Addressable::URI.join(prx_root, story.id.to_s) if story
  end

  def published
    @overrides[:published]
  end
end
