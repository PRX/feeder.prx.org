class Uncut < MediaResource
  DURATION_TOLERANCE = 0.5 # half a second
  DEFAULT_SEGMENTATION = [[nil, nil]].freeze
  include MetadataBreaks

  validates :medium, inclusion: {in: %w[audio]}, if: :status_complete?
  validates :duration, numericality: {greater_than: 0}, if: :status_complete?
  validate :validate_segmentation

  before_validation :set_defaults

  def set_defaults
    self.segmentation ||= DEFAULT_SEGMENTATION
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

    unless valid_segments?(segmentation) && ordered_segments?(segmentation) && non_empty_segments?(segmentation)
      errors.add(:segmentation, :bad_segmentation, message: "bad segmentation")
    end
  end

  def segmentation_ready?
    if status_complete? && valid? && segmentation_matches_segment_count?
      last_start, last_end = segmentation.last
      last_start.to_f < duration && last_end.to_f < duration
    else
      false
    end
  end

  def sanitize_segmentation
    (segmentation || []).filter_map do |start, stop|
      if start.to_f < duration && stop.to_f < duration
        [start, stop]
      elsif start.to_f < duration
        [start, nil]
      end
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
    breaks = (breaks || [])
      .compact
      .reject { |item| !item.is_a?(Array) && item.to_f == 0.0 }
      .sort { |a, b| Array(a).first.to_f <=> Array(b).first.to_f }
      .uniq
    self.segmentation =
      if breaks.is_a?(Array) && breaks.present?
        breaks = breaks.prepend(nil) if add_start_time?(breaks)
        breaks = breaks.append(nil) if add_end_time?(breaks)
        breaks.each_cons(2).map do |start, stop|
          [start.try(:last) || start, stop.try(:first) || stop]
        end
      else
        DEFAULT_SEGMENTATION
      end
  end

  # If there is already a first 0 or nil, don't add another
  def add_start_time?(breaks)
    first_val = if breaks.first.is_a?(Array)
      breaks.first.first
    else
      breaks.first
    end
    if first_val.nil? || first_val.to_f <= 0.0
      false
    else
      within_tolerance = first_val.to_f < DURATION_TOLERANCE
      !within_tolerance
    end
  end

  # If there is already a last ~duration or nil, don't add another
  def add_end_time?(breaks)
    last_val = if breaks.last.is_a?(Array)
      breaks.last.last
    else
      breaks.last
    end
    if last_val.nil?
      false
    elsif duration.to_f <= 0.0
      true
    else
      last_val = [last_val.to_f, duration.to_f].min
      within_tolerance = duration.to_f - last_val < DURATION_TOLERANCE
      !within_tolerance
    end
  end

  private

  def segmentation_matches_segment_count?
    if segmentation.present?
      episode.segment_count.nil? || segmentation&.count.to_i == episode.segment_count
    else
      false
    end
  end

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

  def non_empty_segments?(segs)
    segs.all? { |s1, s2| s1.nil? || s2.nil? || s1 < s2 }
  end

  def valid_number?(n)
    n.is_a?(Numeric) && n.positive?
  end
end
