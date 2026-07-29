class VideoUncut < Uncut
  def validate_episode_medium
    errors.add(:medium, :not_video, message: "must be a video file") if medium != "video"
  end

  def copy_media(force = false)
    if force || needs_copy?
      Tasks::CopyMediaTask.start!(self)
    end
  end

  def build_content(seg)
    VideoContent.new(original_url: url, segmentation: seg)
  end
end
