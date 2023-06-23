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
    segs.is_a?(Array) && segmentation.each_with_index.all? { |s, i| valid_segment?(s, i, segs.length) }
  end

  def ordered_segments?(segs)
    segs.flatten.compact == segs.flatten.compact.sort
  end

  # must be either a single number (cut point) or array of 2 numbers (cut range)
  def valid_segment?(segment, index, length)
    if valid_number?(segment)
      true
    elsif segment.is_a?(Array) && segment.length == 2
      s1, s2 = segment

      # first/last segments can have a nil, to indicate trimming the file
      if index == 0
        (valid_number?(s1) || s1.nil?) && valid_number?(s2)
      elsif index == length - 1
        valid_number?(s1) && (valid_number?(s2) || s2.nil?)
      else
        valid_number?(s1) && valid_number?(s2)
      end
    else
      false
    end
  end

  def valid_number?(n)
    n.is_a?(Numeric) && n.positive?
  end
end
