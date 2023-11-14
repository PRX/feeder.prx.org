class EpisodeRssImport < EpisodeImport
  store :config, accessors: [:entry, :audio], coder: JSON

  validates :guid, presence: true

  def set_defaults
    super
    self.audio ||= {files: []}
  end

  def import!
    status_started!
    set_audio_metadata!

    status_importing!
    create_or_update_episode!
    set_file_resources!

    episode.save!
    episode.copy_media

    status_complete!
  rescue => err
    status_error!
    raise err
  end

  def audio_content_params
    audio&.fetch("files")&.each_with_index&.map do |url, index|
      {position: index, original_url: url}
    end
  end

  def image_contents_params
    if (image = entry[:itunes_image])
      {original_url: image}
    end
  end

  def set_audio_metadata!
    audio_files = entry_audio_files(entry)
    update!(audio: audio_files)
  end

  def set_file_resources!
    content = audio_content_params
    episode.media = content
    episode.segment_count = content&.size
    episode.image = image_contents_params
    episode.save!
    episode.images.reset
    episode.contents.reset
  end

  def entry_audio_files(entry)
    if config[:audio] && config[:audio][entry[:entry_id]]
      {files: (config[:audio][entry[:entry_id]] || [])}
    elsif (enclosure = enclosure_url(entry))
      {files: [enclosure]}
    end
  end

  def create_or_update_episode!
    lookup = Episode.where(podcast_id: podcast.id).find_by_item_guid(guid)

    if lookup.present?
      self.episode = lookup
    else
      self.episode ||= Episode.new(podcast: podcast)
    end

    update_episode_with_entry!

    episode.save!
  end

  def update_episode_with_entry!
    episode.clean_title = entry[:itunes_title]
    episode.description = entry_description(entry)
    episode.episode_number = entry[:itunes_episode]
    episode.published_at = entry[:published]
    episode.season_number = entry[:itunes_season]
    episode.subtitle = clean_string(episode_short_desc(entry))
    episode.categories = Array(entry[:categories]).map(&:strip).reject(&:blank?)
    episode.title = clean_title(entry[:title])

    if entry[:itunes_summary] && entry_description_attribute(entry) != :itunes_summary
      episode.summary = clean_text(entry[:itunes_summary])
    end
    episode.author = person(entry[:itunes_author] || entry[:author] || entry[:creator])
    episode.block = (clean_string(entry[:itunes_block]) == "yes")
    episode.explicit = explicit(entry[:itunes_explicit])
    episode.original_guid = clean_string(entry[:entry_id])
    episode.is_closed_captioned = closed_captioned?(entry)
    episode.is_perma_link = entry[:is_perma_link]
    episode.keywords = (entry[:itunes_keywords] || "").split(",").map(&:strip)
    episode.position = entry[:itunes_order]
    episode.url = episode_url(entry)
    episode.itunes_type = entry[:itunes_episode_type] unless entry[:itunes_episode_type].blank?

    episode
  end

  def entry_description(entry)
    atr = entry_description_attribute(entry)
    clean_text(entry[atr])
  end

  def entry_description_attribute(entry)
    [:content, :itunes_summary, :description, :title].find { |d| !entry[d].blank? }
  end

  def title
    clean_title(entry[:title])
  end

  def episode_url(entry)
    url = clean_string(entry[:feedburner_orig_link] || entry[:url] || entry[:link])
    if /libsyn\.com/.match?(url)
      url = nil
    end
    url
  end

  def closed_captioned?(entry)
    (clean_string(entry[:itunes_is_closed_captioned]) == "yes")
  end

  def episode_short_desc(item)
    [item[:itunes_subtitle], item[:description], item[:title]].find do |field|
      !field.blank? && field.split.length < 50
    end
  end
end
