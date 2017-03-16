require 'episode'

class EpisodeEntryHandler
  ENTRY_ATTRIBUTES = %w(author block categories content description explicit
    feedburner_orig_enclosure_link feedburner_orig_link is_closed_captioned
    is_perma_link keywords position subtitle summary title url).freeze

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
    update_enclosure
    update_contents
    update_image
    update_link
  end

  def update_guid
    self.episode.original_guid = overrides[:guid]
  end

  def update_dates
    self.episode.published_at = Time.parse(overrides[:published]) if overrides[:published]
    self.episode.updated_at = Time.parse(overrides[:updated]) if overrides[:updated]
  end

  def update_link
    self.episode.url = overrides[:feedburner_orig_link] || overrides[:url] || overrides[:link]
    # libsyn sets link to the libsyn mp3; nil it out (in rss, will fallback on the enclosure url)
    self.episode.url = nil if episode.url && episode.url.match(/libsyn\.com/)
  end

  def update_enclosure
    enclosure_hash = overrides.fetch(:enclosure, {}).dup
    if overrides[:feedburner_orig_enclosure_link]
      enclosure_hash[:url] = overrides[:feedburner_orig_enclosure_link]
    end

    if overrides[:enclosure]
      enclosure_file = URI.parse(enclosure_hash[:url] || '').path.split('/').last
      if !episode.enclosures.where('original_url like ?', "%/#{enclosure_file}").exists?
        episode.enclosures << Enclosure.build_from_enclosure(episode, enclosure_hash)
      end
    else
      episode.enclosures.destroy_all
    end
  end

  def update_image
    if image_url = overrides[:image_url]
      episode.images.build(original_url: image_url) if !episode.find_existing_image(image_url)
    else
      episode.images.destroy_all
    end
  end

  def update_contents
    new_contents = Array(overrides[:contents]).sort_by { |c| c[:position] }

    if new_contents.blank?
      episode.contents.destroy_all
      return
    end

    new_contents.each do |c|
      # If there is an existing file with the same filename, then update
      if existing_content = episode.find_existing_content(c[:position], c[:url])
        existing_content.update_with_content!(c)
      # else if there is no file, or the filename in the url is different
      # then make a new content to be or replace content for that position
      else
        new_content = Content.build_from_content(episode, c)
        episode.all_contents << new_content
      end
    end

    # find all contents with a greater position than last file and whack them
    max_pos = new_contents.last[:position]
    episode.all_contents.where(['position > ?', max_pos]).delete_all
  end
end
