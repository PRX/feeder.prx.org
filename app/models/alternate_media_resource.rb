class AlternateMediaResource < MediaResource
  COPY_FIELDS = %i[
    bit_rate
    channels
    duration
    episode_id
    file_size
    frame_rate
    height
    lang
    medium
    mime_type
    sample_rate
    segmentation
    width
  ]

  def self.from_uncut(uncut)
    new(uncut.slice(*COPY_FIELDS).merge(original_url: uncut.url))
  end

  def same_uncut?(uncut)
    original_url == uncut.url && segmentation == uncut.segmentation
  end

  def file_name
    "index.m3u8"
  end

  def media_url
    "#{episode.base_published_url}/#{guid}/index.m3u8" if episode
  end

  # NOTE: all playlists and ts files are in a subdir
  def variant_url(file_name)
    "#{File.dirname(url)}/#{file_name}"
  end

  def variant_path(file_name)
    "#{File.dirname(path)}/#{file_name}"
  end

  def copy_media(force = false)
    if force || needs_copy?
      Tasks::TranscodeHlsTask.start!(self)
    end
  end

  def after_hls_transcode(task)
    # TODO: should this kick off publishing or something?
  end

  def replace_resources!
    AlternateMediaResource.where(episode_id: episode_id).where.not(id: id).destroy_all
  end
end
