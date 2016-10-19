require 'episode'

class EpisodeStoryHandler
  attr_accessor :episode, :story

  def initialize(episode)
    self.episode = episode
  end

  def self.create_from_story!(story)
    series_uri = story.links['series'].href
    podcast = Podcast.find_by!(prx_uri: series_uri)
    episode = Episode.new(podcast: podcast)
    update_from_story!(episode, story)
  end

  def self.update_from_story!(episode, story)
    new(episode).update_from_story!(story)
  end

  def update_from_story!(story)
    Episode.transaction do
      episode.lock!
      update_from_story(story)
      episode.save!
    end
    episode
  end

  def update_from_story(story)
    self.story = story
    self.episode.prx_uri = story.links['self'].href
    self.episode.url = story.links['alternate'].try(:href)

    update_attributes
    update_audio
  end

  def update_attributes
    sa = story.attributes
    self.episode.title = sa[:title]
    self.episode.subtitle = Sanitize.fragment(sa[:short_description] || '').strip
    self.episode.description = Sanitize.fragment(sa[:description] || '').strip
    self.episode.summary = sa[:description]
    self.episode.content = sa[:description]
    self.episode.categories = sa[:tags]
    self.episode.published_at = Time.parse(sa[:published_at]) if sa[:published_at]
  end

  def update_audio
    audio = story.objects["prx:audio"].objects['prx:items'] rescue []
    audio.each do |a|
      next unless a.status == 'complete'

      existing_content = find_existing_content(a)

      if existing_content
        # update it? maybe not
      else
        episode.all_contents << build_content(a)
      end

    end
    max_pos = audio.last.try(:position).to_i
    episode.all_contents.where(['position > ?', max_pos]).delete_all if max_pos > 0
  end

  def build_content(audio)
    Content.new.tap do |c|
      c.position = audio.attributes['position']
      c.original_url = audio.links['enclosure'].href
      c.mime_type = audio.links['enclosure'].type || audio.attributes['content_type']
      c.file_size = audio.attributes['size']
      c.duration = audio.attributes['duration']
      c.bit_rate = audio.attributes['bit_rate']
      c.sample_rate = audio.attributes['frequency'] * 1000 if audio.attributes['frequency']
    end
  end

  def find_existing_content(audio)
    episode.all_contents.
      where(position: audio.position, original_url: audio.links['enclosure'].href).
      order(created_at: :desc).
      first
  end
end
