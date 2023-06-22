class Uncut < MediaResource
  after_save :cut_contents

  validates :medium, inclusion: {in: %w[audio]}, if: :status_complete?
  validate :validate_segmentation

  def cut_contents
    if status_complete? && segmentation.present? && segmentation_previously_changed?
      # TODO
    end
  end

  def generate_waveform?
    true
  end

  def validate_segmentation
    return if segmentation.nil?

    unless valid_segments?(segmentation) && ordered_segments?(segmentation)
      errors.add(:segmentation, :bad_segmentation, message: "bad segmentation")
    end
  end

  private

  def valid_segments?(segs)
    segs.is_a?(Array) && segmentation.all? { |s| valid_segment?(s) }
  end

  def ordered_segments?(segs)
    segs.flatten == segs.flatten.sort
  end

  # must be either a single number (cut point) or array of 2 numbers (cut range)
  def valid_segment?(s)
    if valid_number?(s)
      true
    else
      s.is_a?(Array) && s.length == 2 && valid_number?(s[0]) && valid_number?(s[1])
    end
  end

  def valid_number?(n)
    n.is_a?(Numeric) && (n.zero? || n.positive?)
  end
end
