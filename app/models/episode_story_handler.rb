require 'episode'

class EpisodeStoryHandler
  attr_accessor :episode
  delegate :overrides, to: :episode

  def initialize(episode)
    self.episode = episode
  end

  def self.create_from_story!(story)
    series_uri = story.links['series'].href
    story_uri = story.links['self'].href
    podcast = Podcast.find_by!(prx_uri: series_uri)
    published = story.attributes[:published_at]
    published = Time.parse(published) if published

    Episode.create!(podcast: podcast, prx_uri: story_uri, published_at: published)
  end

  def self.update_from_story!(episode, story)
    new(episode).update_from_story!(story)
  end

  def update_from_story!(story)
    episode.tap { |s| s.touch }
  end
end
