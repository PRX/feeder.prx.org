class Content < MediaResource
  after_save :publish_episode!

  validate :validate_episode_medium, if: :status_complete?
  validate :validate_slices

  def validate_episode_medium
    if episode&.medium_video?
      errors.add(:medium, :not_video, message: "must be a video file") if medium != "video"
    elsif episode&.medium_audio? || episode&.medium_uncut?
      errors.add(:medium, :not_audio, message: "must be an audio file") if medium != "audio"
    end
  end

  def validate_slices
    return if segmentation.nil?

    # slices can be [1.23, 4.56] or [nil, 4.56] or [1.23, nil]
    unless slices_array? && slices_numeric? && slices_ordered?
      errors.add(:segmentation, :bad_slices, message: "bad slices")
    end
  end

  def slice_start
    segmentation.try(:[], 0)
  end

  def slice_start=(time)
    self.segmentation = [time.try(:zero?) ? nil : time, slice_end]
  end

  def slice_end
    segmentation.try(:[], 1)
  end

  def slice_end=(time)
    self.segmentation = [slice_start, time]
  end

  def publish_episode!
    episode&.publish! if status_complete? && status_previously_changed?
  end

  def replace?(res)
    super || segmentation != res.try(:segmentation)
  end

  def replace_resources!
    Content.where(episode_id: episode_id, position: position).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end

  private

  def slices_array?
    segmentation.is_a?(Array) && segmentation.length == 2 && segmentation.compact.length >= 1
  end

  def slices_numeric?
    [slice_start, slice_end].compact.all? { |s| s.is_a?(Numeric) && s.positive? }
  end

  def slices_ordered?
    slice_start.nil? || slice_end.nil? || (slice_start < slice_end)
  end
end
