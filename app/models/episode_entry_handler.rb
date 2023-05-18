require "episode"

class EpisodeEntryHandler
  ENTRY_ATTRIBUTES = %w[author block categories content description explicit
    feedburner_orig_enclosure_link feedburner_orig_link is_closed_captioned
    is_perma_link keywords position subtitle summary title url
    season_number episode_number clean_title].freeze

  attr_accessor :episode
  delegate :overrides, to: :episode

  def initialize(episode)
    self.episode = episode
  end

  def self.create_from_entry!(podcast, entry)
    episode = Episode.new(podcast: podcast)
    update_from_entry!(episode, entry)
  end

  def self.update_from_entry!(episode, entry)
    new(episode).update_from_entry!(entry)
  end

  def update_from_entry!(entry)
    Episode.transaction do
      episode.lock!
      update_from_entry(entry)
      episode.save!
    end
    episode
  end

  def update_from_entry(entry)
    episode.overrides = entry.attributes.with_indifferent_access
    update_from_overrides
  end

  def update_from_overrides
    o = overrides.slice(*ENTRY_ATTRIBUTES).with_indifferent_access
    episode.assign_attributes(o)

    update_guid
    update_dates
    update_contents
    update_image
    update_link
  end

  def update_guid
    episode.original_guid = overrides[:guid]
  end

  def update_dates
    episode.published_at = Time.parse(overrides[:published]) if overrides[:published]
    episode.updated_at = Time.parse(overrides[:updated]) if overrides[:updated]
  end

  def update_link
    episode.url = overrides[:feedburner_orig_link] || overrides[:url] || overrides[:link]
    # libsyn sets link to the libsyn mp3; nil it out (in rss, will fallback on the enclosure url)
    episode.url = nil if episode.url&.match(/libsyn\.com/)
  end

  def update_image
    episode.image = overrides[:image_url]
  end

  def update_contents
    new_contents = Array(overrides[:contents]).sort_by { |c| c[:position] }
    episode.media = new_contents.map { |c| c[:url] }
  end
end
