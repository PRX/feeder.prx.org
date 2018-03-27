require 'episode'

class EpisodeStoryHandler
  include PRXAccess

  attr_accessor :episode, :story

  def initialize(episode)
    self.episode = episode
  end

  def self.create_from_story!(story)
    series_uri = story.links['series'].href
    if podcast = Podcast.find_by(prx_uri: series_uri)
      episode = Episode.new(podcast: podcast)
      update_from_story!(episode, story)
    end
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
    episode.prx_uri = Episode.story_uri(story)

    update_attributes
    update_audio
    update_image
  end

  def update_attributes
    sa = story.attributes

    versions = story.objects['prx:audio-versions'].objects['prx:items'] rescue []
    if !versions.blank?
      va = versions.first.attributes
      episode.explicit = va['explicit']
    end

    updated = Time.parse(sa[:updated_at]) if sa[:updated_at]
    if updated && (episode.source_updated_at.nil? || updated > episode.source_updated_at)
      episode.source_updated_at = updated
    end

    episode.title = sa[:title]
    episode.clean_title = sa[:clean_title]
    episode.subtitle = sa[:short_description]
    episode.description = sa[:description]
    episode.content = sa[:description]
    episode.categories = sa[:tags]
    episode.published_at = sa[:published_at] ? Time.parse(sa[:published_at]) : nil

    %w(season episode).each do |time|
      id = sa["#{time}_identifier"]
      episode["#{time}_number"] = id.to_i if id && (!id.to_i.zero? || [0, '0'].include?(id))
    end
  end

  def update_audio
    audio = story.objects['prx:audio'].objects['prx:items'] rescue []
    audio.each do |a|
      next unless a.status == 'complete'

      existing_content = episode.find_existing_content(a.position, a.links['prx:storage'].href)
      if existing_content
        update_content(existing_content, a)
      else
        episode.all_contents << build_content(a)
      end
    end
    max_pos = audio.last.try(:position).to_i
    episode.all_contents.where(['position > ?', max_pos]).delete_all if max_pos > 0
  end

  def update_image
    if image_url = story.objects['prx:image'].links['original'].href rescue nil
      episode.images.build(original_url: image_url) if !episode.find_existing_image(image_url)
    else
      episode.images.destroy_all
    end
  end

  def build_content(audio)
    update_content(Content.new, audio)
  end

  def update_content(c, audio)
    c.position = audio.attributes['position']
    c.href = audio.links['prx:storage'].href
    c.mime_type = audio.links['prx:storage'].type || audio.attributes['content_type']
    c.file_size = audio.attributes['size']
    c.duration = audio.attributes['duration']
    c.bit_rate = audio.attributes['bit_rate']
    c.sample_rate = audio.attributes['frequency'] * 1000 if audio.attributes['frequency']
    c
  end

  def get_story(account = nil)
    return nil unless episode.prx_uri
    api(account: account).tap { |a| a.href = episode.prx_uri }.get
  end
end
