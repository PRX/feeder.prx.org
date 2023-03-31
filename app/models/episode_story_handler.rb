require "episode"

class EpisodeStoryHandler
  include PrxAccess

  attr_accessor :episode, :story

  def initialize(episode)
    self.episode = episode
  end

  def self.create_from_story!(story)
    series_uri = story.links["series"].href
    if (podcast = Podcast.find_by(prx_uri: series_uri))
      episode = Episode.new(podcast: podcast)
      update_from_story!(episode, story)
    end
  end

  def self.update_from_story!(episode, story = nil)
    handler = new(episode)
    handler.update_from_story!(story || handler.get_story)
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

    update_story_attributes
    update_audio
    update_image
  end

  def update_story_attributes
    sa = story.attributes

    versions = story.objects["prx:audio-versions"]&.objects&.[]("prx:items")
    if !versions.blank?
      version = versions.first
      episode.prx_audio_version_uri = version.href
      episode.audio_version = version.attributes[:label] # TODO: is this right?
      episode.segment_count = version.attributes[:segment_count]
      episode.explicit = version.attributes[:explicit]
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
    episode.production_notes = sa[:production_notes]
    episode.published_at = sa[:published_at] ? Time.parse(sa[:published_at]) : nil
    episode.released_at = sa[:released_at] ? Time.parse(sa[:released_at]) : nil

    %w[season episode].each do |time|
      id = sa["#{time}_identifier"].to_i
      episode["#{time}_number"] = id.positive? ? id : nil
    end
  end

  def update_audio
    audio = begin
      story.objects["prx:audio"].objects["prx:items"]
    rescue
      []
    end

    episode.contents = audio.map do |a|
      Content.build(a.links["prx:storage"].href, a.position)
    end
  end

  def update_image
    cms_image = begin
      story.objects["prx:image"] || story.links["prx:image"]
    rescue
      nil
    end
    cms_href = begin
      cms_image.links["original"].href
    rescue
      nil
    end

    episode.image = cms_href

    if cms_href.present?
      episode.image.caption = cms_image.attributes["caption"]
      episode.image.credit = cms_image.attributes["credit"]
    end
  end

  def build_content(audio)
    update_content(Content.new, audio)
  end

  def update_content(content, audio)
    content.tap do |c|
      c.position = audio.attributes["position"]
      c.href = audio.links["prx:storage"].href
      c.mime_type = audio.links["prx:storage"].type || audio.attributes["content_type"]
      c.file_size = audio.attributes["size"]
      c.duration = audio.attributes["duration"]
      c.bit_rate = audio.attributes["bit_rate"]
      c.sample_rate = audio.attributes["frequency"] * 1000 if audio.attributes["frequency"]
    end
  end

  def get_story(account = nil)
    return nil unless episode.prx_uri

    api(account: account).tap { |a| a.href = episode.prx_uri }.get
  end
end
