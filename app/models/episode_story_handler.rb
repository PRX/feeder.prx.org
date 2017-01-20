require 'episode'

class EpisodeStoryHandler
  include PRXAccess

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

  def self.update_from_story!(episode, story = nil)
    story ||= get_story
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
    episode.prx_uri = story.links['self'].href
    episode.url = story.links['alternate'].try(:href)

    update_attributes
    update_audio
  end

  def update_attributes
    sa = story.attributes

    updated = Time.parse(sa[:updated_at]) if sa[:updated_at]
    if updated && (episode.updated_at.nil? || updated > episode.updated_at)
      episode.updated_at = updated
    end

    episode.title = sa[:title]
    episode.subtitle = Sanitize.fragment(sa[:short_description] || '').strip
    episode.description = Sanitize.fragment(sa[:description] || '').strip
    episode.summary = sa[:description]
    episode.content = sa[:description]
    episode.categories = sa[:tags]
    episode.published_at = Time.parse(sa[:published_at]) if sa[:published_at]
  end

  def update_audio
    audio = story.objects['prx:audio'].objects['prx:items'] rescue []
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
      c.original_url = audio_url(audio.links['enclosure'].href)
      c.mime_type = audio.links['enclosure'].type || audio.attributes['content_type']
      c.file_size = audio.attributes['size']
      c.duration = audio.attributes['duration']
      c.bit_rate = audio.attributes['bit_rate']
      c.sample_rate = audio.attributes['frequency'] * 1000 if audio.attributes['frequency']
    end
  end

  def find_existing_content(audio)
    episode.all_contents.
      where(position: audio.position, original_url: audio_url(audio.links['enclosure'].href)).
      order(created_at: :desc).
      first
  end

  def audio_url(url)
    if url =~ /^http/
      url
    else
      path_to_url(ENV['CMS_HOST'], url)
    end
  end

  def path_to_url(host, path)
    if host =~ /\.org/ # TODO: should .tech's be here too?
      URI::HTTPS.build(host: host, path: path).to_s
    else
      URI::HTTP.build(host: host, path: path).to_s
    end
  end

  def get_story(account = nil)
    return nil unless episode.prx_uri
    api(account: account).tap { |a| a.href = episode.prx_uri }.get
  end
end
