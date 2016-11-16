require 'episode'

class EpisodeEntryHandler
  ENTRY_ATTRIBUTES = %w(author block categories content description explicit
    feedburner_orig_enclosure_link feedburner_orig_link image_url is_closed_captioned
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
    # must come after update_enclosure & update_contents, depends on media_url
    update_link
  end

  def update_guid
    self.episode.original_guid = overrides[:guid]
  end

  def update_dates
    self.episode.published = Time.parse(overrides[:published]) if overrides[:published]
    self.episode.updated = Time.parse(overrides[:updated]) if overrides[:updated]
    self.episode.published_at = episode.published || episode.updated
  end

  # must be called after update_enclosure and update_contents
  # as it depends on media_url
  def update_link
    self.episode.url = overrides[:feedburner_orig_link] || overrides[:url] || overrides[:link]
    # libsyn sets the link to a libsyn url, instead set to media file or page
    self.episode.url = episode.media_url if episode.url && episode.url.match(/libsyn\.com/)
  end

  def update_enclosure
    enclosure_hash = overrides.fetch(:enclosure, {}).dup
    if overrides[:feedburner_orig_enclosure_link]
      enclosure_hash[:url] = overrides[:feedburner_orig_enclosure_link]
    end

    # If the enclosure has been removed, just delete it (rare but simple case)
    if !overrides[:enclosure]
      episode.enclosure.try(:destroy)
    else
      # If no enclosure exists for this url (of any status), create one
      enclosure_file = URI.parse(enclosure_hash[:url] || '').path.split('/').last
      if !episode.enclosures.where('original_url like ?', "%/#{enclosure_file}").exists?
        episode.enclosures << Enclosure.build_from_enclosure(episode, enclosure_hash)
      end
    end
  end

  def update_contents
    new_contents = Array(overrides[:contents]).sort_by { |c| c[:position] }

    if new_contents.blank?
      episode.contents.destroy_all
      return
    end

    final_contents = []
    new_contents.each do |c|
      existing_content = find_existing_content(c)

      # If there is an existing file with the same url, update
      if existing_content
        existing_content.update_with_content!(c)
        final_contents << existing_content

      # Otherwise, make a new content to be or replace content for that position
      # If there is no file, or the file has a different url
      else
        new_content = Content.build_from_content(episode, c)
        episode.all_contents << new_content
      end
    end

    # find all contents with a greater position and whack them
    max_pos = new_contents.last[:position]
    episode.all_contents.where(['position > ?', max_pos]).delete_all
  end

  def find_existing_content(c)
    content_file = URI.parse(c[:url] || '').path.split('/').last
    episode.all_contents.
      where(position: c[:position]).
      where('original_url like ?', "%/#{content_file}").
      order(created_at: :desc).
      first
  end
end
