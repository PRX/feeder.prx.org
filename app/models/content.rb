class Content < MediaResource
  after_save :publish_episode!

  validate :validate_episode_medium, if: :status_complete?
  validate :validate_segmentation

  def validate_episode_medium
    if episode&.medium_video?
      errors.add(:medium, :not_video, message: "must be a video file") if medium != "video"
    elsif episode&.medium_audio? || episode&.medium_uncut?
      errors.add(:medium, :not_audio, message: "must be an audio file") if medium != "audio"
    end
  end

  def validate_segmentation
    return if segmentation.nil?

    # can be [1.23, 4.56] or [nil, 4.56] or [1.23, nil] or [nil, nil]
    unless array_segments? && numeric_segments? && ordered_segments?
      errors.add(:segmentation, :bad_slices, message: "bad slices")
    end
  end

  def slice?
    segmentation.present? && (slice_start.present? || slice_end.present?)
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

  def becomes_uncut
    self.type = "Uncut"
    self.position = nil
    self.segmentation = nil
    becomes(Uncut)
  end

  private

  def array_segments?
    segmentation.is_a?(Array) && segmentation.length == 2
  end

  def numeric_segments?
    [slice_start, slice_end].compact.all? { |s| s.is_a?(Numeric) && s.positive? }
  end

  def ordered_segments?
    slice_start.nil? || slice_end.nil? || (slice_start < slice_end)
  end
end
