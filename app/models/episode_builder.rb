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
    @story = get_story
    sa = @story.attributes
    HashWithIndifferentAccess.new(
      title: sa[:title],
      description: {
        rich: sa[:description] || '',
        plain: Sanitize.fragment(sa[:description] || '').strip
      },
      guid:  "prx:#{@ep.story_id}:#{@ep.guid}",
      link: link,
      audio: audio_file(@ep),
      short_description: sa[:shortDescription],
      explicit: sa[:contentAdvisory] ? 'yes' : 'no',
      keywords: sa[:tags].join(', '),
      categories: sa[:tags].join(', '),
      created: @ep.created_at,
      modified: @ep.updated_at
    ).merge(@overrides)
  end

  def audio_file(episode)
    info = episode.enclosure_info
    info[:url] = prefix_audio_url(info[:url])
    info
  end

  def prefix_audio_url(url)
    return url if prefix.blank?

    link = url.sub(/^http(s*):\/\//, '/')
    extension = URI.parse(url).path.split('.').pop
    prefix + extension + link
  end

  def get_story(account = nil)
    api(account).tap { |a| a.href = @prx_uri }.get
  end

  def link
    "#{prx_root}#{@story.id}"
  end

  def prefix
    ENV['AUDIO_FILE_PREFIX'] || ''
  end
end
