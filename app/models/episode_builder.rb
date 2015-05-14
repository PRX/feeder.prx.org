class EpisodeBuilder

  def self.from_prx_story(opts = {})
    new(opts).from_prx_story
  end

  def initialize(e)
    @ep = e
    @prx_id = e.prx_id
    @overrides = JSON.parse(e.overrides || '{}').symbolize_keys!
  end

  def from_prx_story
    get_story

    {
      title: @story.title,
      description: {
        rich: @story.description,
        plain: Sanitize.fragment(@story.description).strip
      },
      author_name: author["name"],
      link: link,
      audio_file: audio_file[:location],
      audio_file_type: audio_file[:type],
      length: @story.duration,
      short_description: @story.shortDescription,
      explicit: @story.contentAdvisory ? 'yes' : 'no',
      keywords: @story.tags.join(', '),
      categories: @story.tags.join(', '),
      created: @ep.created_at.strftime('%a, %d %b %Y %H:%M:%S %Z'),
      modified: @ep.updated_at.strftime('%a, %d %b %Y %H:%M:%S %Z')
    }.merge(@overrides)
  end

  def audio_file
    audio = @story.audio[0].body["_links"]["enclosure"]
    link = audio["href"].to_s
    extension = link.split('.').pop

    {
      location: prefix + extension + link,
      type: audio["type"]
    }
  end

  def author
    @story.account.body
  end

  def get_story
    @story = api.get.links.story[0].where(id: @prx_id)
  end

  def api
    HyperResource.new(root: cms_root)
  end

  def link
    "#{prx_root}#{@story.id}"
  end

  def cms_root
    ENV['CMS_ROOT'] || 'https://cms.prx.org/api/vi/'
  end

  def prx_root
    ENV['PRX_ROOT'] || 'https://beta.prx.org/stories/'
  end

  def prefix
    ENV['AUDIO_FILE_PREFIX'] || ''
  end
end
