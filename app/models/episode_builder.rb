require 'addressable/uri'
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
      audio: @ep.enclosure_info,
      image_url: nil,
      created: @ep.created_at,
      modified: @ep.updated_at,
      published: @ep.published_at
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
        published: sa[:publishedAt]
      )
      info.merge!(story_info)
    end

    info.merge!(@overrides) if @overrides

    if info[:published] && info[:published].is_a?(String)
      info[:published] = Time.parse(info[:published])
    end

    info
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
