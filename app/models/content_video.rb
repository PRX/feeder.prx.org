class ContentVideo < Content
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
end
