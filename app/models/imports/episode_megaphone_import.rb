class EpisodeMegaphoneImport < EpisodeImport
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
    episode.uncut&.slice_contents!
    episode.copy_media

    status_complete!
  rescue => err
    status_error!
    raise err
  end

  def set_audio_metadata!
    audio_files = megaphone_audio_files(entry)
    update!(audio: audio_files)
  end

  def set_file_resources!
    if upload_audio?
      if !episode.uncut.present?
        ad_breaks = entry_ad_breaks(entry)
        episode.segment_count = ad_breaks.length + 1
        episode.uncut = Uncut.new(href: entry_audio_file(entry))
        if ad_breaks.size > 0
          episode.uncut.ad_breaks = ad_breaks
        end
      end
    elsif (entry[:expected_adhash] || "").match?("1")
      # base segment count on the adhash - we don't know how many breaks there are
      # but we know there is at least one ad break if the adhash contains a "1"
      episode.segment_count = 2
    end

    if !episode.image.present? && entry[:image_file].present?
      episode.image = entry[:image_file]
    end

    episode.save!

    episode.contents.reset
    episode.images.reset
  end

  def upload_audio?
    audio[:files].present? &&
      audio[:files].length > 1 &&
      audio[:files].all? { |f| (f || "").start_with?("http") }
  end

  # eventually replace this with a call to a lamdda to join the audio and id3 files
  def entry_audio_file(entry)
    path = upload_path(entry)
    upload_audio(path)
    "s3://#{ENV["UPLOAD_BUCKET_NAME"]}/#{path}"
  end

  # filter out if they are at the start or very end of the file
  def entry_ad_breaks(entry)
    return [] if entry[:insertion_points].blank? || entry[:duration].blank?
    min_s = 1
    max_s = entry[:duration].to_f - 1.0
    entry[:insertion_points].select { |num| num > min_s && num < max_s }
  end

  def megaphone_audio_files(entry)
    id3_file = entry[:id3_file]
    audio_file = entry[:audio_file]
    {files: [id3_file, audio_file]}
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
    episode.original_guid = clean_string(entry[:guid] || entry[:parent_id] || entry[:id])
    if entry[:draft]
      episode.released_at = entry[:pubdate]
    else
      episode.published_at = entry[:pubdate]
    end
    episode.title = clean_title(entry[:title])
    episode.clean_title = clean_title(entry[:clean_title])
    episode.subtitle = clean_string(entry[:subtitle])
    episode.description = clean_text(entry[:summary])
    episode.episode_number = entry[:episode_number]
    episode.season_number = entry[:season_number]
    episode.url = entry[:link]
    episode.author = person(entry[:author])
    episode.explicit = explicit(entry[:explicit])
    episode.itunes_type = entry[:episode_type] || "full"
    episode.categories = ["adfree"] if entry[:ad_free]

    episode
  end

  def upload_audio(path)
    audio_files = audio[:files]
    return if audio_files.blank? || audio_files.length < 2
    combined_file = Tempfile.new(["megaphone_combined_audio", ".mp3"])
    combined_file.binmode
    audio_files.each do |url|
      download_file(combined_file, url)
    end
    combined_file.rewind

    # upload the combined file to S3
    put_file(combined_file, path)
  ensure
    combined_file&.close
    combined_file&.unlink
  end

  def put_file(file, path)
    bucket = Aws::S3::Resource.new.bucket(ENV["UPLOAD_BUCKET_NAME"])
    bucket.object(path).put(body: file)
  end

  def upload_path(entry)
    filename = entry[:original_filename] || (entry[:id] + ".mp3")
    "#{uploads_prefix}/#{Date.today.strftime("%Y-%m-%d")}/#{SecureRandom.uuid}/#{filename}"
  end

  def uploads_prefix
    if ENV["UPLOAD_BUCKET_PREFIX"].present?
      ENV["UPLOAD_BUCKET_PREFIX"]
    else
      Rails.env
    end
  end
end
