class Content < MediaResource
  after_save :publish_episode!

  validate :validate_episode_medium, if: :status_complete?

  def validate_episode_medium
    if episode&.medium_video?
      errors.add(:medium, :not_video, message: "must be a video file") if medium != "video"
    elsif episode&.medium_audio? || episode&.medium_uncut?
      errors.add(:medium, :not_audio, message: "must be an audio file") if medium != "audio"
    end
  end

  def publish_episode!
    episode&.publish! if status_complete? && status_previously_changed?
  end

  def replace_resources!
    Content.where(episode_id: episode_id, position: position).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
