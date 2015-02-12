class EpisodeBuilder
  AUDIO_FILE_PREFIX = ENV["AUDIO_FILE_PREFIX"]

  def initialize(opts = {})
    @prx_id = opts[:prx_id]
    @overrides = JSON.parse(opts[:overrides] || '{}').symbolize_keys!
  end

  def api
    @hal_root = ENV['HAL_ROOT']
    HyperResource.new(root: @hal_root)
  end

  def get_story
    @story = api.get.links.story[0].where(id: @prx_id)
  end

  def author
    @story.account.body
  end

  def audio_file
    audio = @story.audio[0].body["_links"]["enclosure"]

    {
      location: AUDIO_FILE_PREFIX + audio["href"].to_s,
      type: audio["type"]
    }
  end

  def self.from_prx_story(opts = {})
    new(opts).from_prx_story
  end

  def link
    ENV['PRX_ROOT'] + @story.id.to_s
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
      itunes_categories: @story.tags.join(', ')
    }.merge(@overrides)
  end
end
