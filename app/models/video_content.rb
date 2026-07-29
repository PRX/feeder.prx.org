class VideoContent < Content
  def validate_episode_medium
    errors.add(:medium, :not_video, message: "must be a video file") if medium != "video"
  end

  def copy_media(force = false)
    if force || needs_copy?
      if slice?
        raise "not supported yet"
      else
        Tasks::TranscodeHlsTask.start!(self)
      end
    end
  end

  def after_copy(copy_task)
  end

  # TODO: need to vary these methods for the "mp3" version, vs the "alt" HLS version
  # episode.url
  # episode.enclosure_url

  # xml.link ep.url || ep.enclosure_url(@feed)
  # xml.enclosure(url: ep.enclosure_url(@feed), type: ep.media_content_type(@feed), length: ep.media_file_size) if ep.media?

  # property :href, readable: false
  # property :file_name
  # property :mime_type, as: :type
  # property :file_size, as: :size
  # property :duration
  # property :status, writeable: false
  # property :href
  # property :original_url, writeable: false

  # link :enclosure do
  #   if represented.podcast && represented.media?
  #     {
  #       href: represented.enclosure_url,
  #       type: represented.media_content_type,
  #       size: represented.media_file_size,
  #       duration: represented.media_duration.to_i,
  #       status: represented.media_status
  #     }
  #   end
  # end
end
