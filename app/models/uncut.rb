class Uncut < MediaResource
  validates :medium, inclusion: {in: %w[audio]}, if: :status_complete?
  validate :validate_segmentation

  before_validation :set_defaults

  def set_defaults
    self.segmentation ||= [[nil, nil]]
  end

  def slice_contents
    if segmentation_ready?
      episode.media = segmentation.map do |seg|
        Content.new(original_url: url, segmentation: seg)
      end
    end
  end

  def slice_contents!
    slice_contents
    episode.save! if episode.contents.any?(&:changed?)
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

  # TODO: not sure if/how to make this a validation - will figure out the UX first
  def segmentation_ready?
    if status_complete? && valid? && segmentation.present?
      if episode.segment_count.nil?
        segmentation.present?
      else
        segmentation&.count.to_i == episode.segment_count
      end
    else
      false
    end
  end

  # the "inverse" of the segmentation - where are the ad break ranges?
  def ad_breaks
    if segmentation.present? && validate(:segmentation)
      segmentation.each_cons(2).map do |seg1, seg2|
        if seg1.last == seg2.first
          seg1.last
        else
          [seg1.last, seg2.first]
        end
      end
    else
      segmentation
    end
  end

  def ad_breaks=(breaks)
    self.segmentation =
      if breaks.is_a?(Array) && breaks.present?
        breaks.prepend(nil).append(nil).each_cons(2).map do |start, stop|
          [start.try(:last) || start, stop.try(:first) || stop]
        end
      else
        breaks
      end
  end

  private

  def valid_segments?(segs)
    return false unless segs.is_a?(Array) && segs.present?
    return false unless segs.all? { |s| s.is_a?(Array) && s.length == 2 }

    # first/last segments can have a nil, to indicate trimming the file
    segs.each_with_index.all? do |segment, index|
      s1, s2 = segment

      if index == 0 && segs.length == 1
        (valid_number?(s1) || s1.nil?) && (valid_number?(s2) || s2.nil?)
      elsif index == 0
        (valid_number?(s1) || s1.nil?) && valid_number?(s2)
      elsif index == segs.length - 1
        valid_number?(s1) && (valid_number?(s2) || s2.nil?)
      else
        valid_number?(s1) && valid_number?(s2)
      end
    end
  end

  def ordered_segments?(segs)
    segs.flatten.compact == segs.flatten.compact.sort
  end

  def valid_number?(n)
    n.is_a?(Numeric) && n.positive?
  end
end
