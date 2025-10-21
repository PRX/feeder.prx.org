class Uncut < MediaResource
  MATCH_TAGS = "AIS_AD_BREAK_"
  MATCH_TAGS_REGEX = /#{MATCH_TAGS}[^=]+=([^;]+)/
  TIMING_TAG_REGEX = /^(?<hours>\d+):(?<minutes>\d+):(?<seconds>\d+)(?::(?<milliseconds>\d+))?$/

  validates :medium, inclusion: {in: %w[audio]}, if: :status_complete?
  validates :duration, numericality: {greater_than: 0}, if: :status_complete?
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
    self.segmentation =
      if breaks.is_a?(Array) && breaks.present?
        if !(breaks.first.is_a?(Array) && (breaks.first.first.to_i == 0))
          breaks = breaks.prepend(nil)
        end
        if !(breaks.last.is_a?(Array) && (breaks.last.last.to_f.round == duration.to_f.round || breaks.last.last.nil?))
          breaks = breaks.append(nil)
        end
        breaks.each_cons(2).map do |start, stop|
          [start.try(:last) || start, stop.try(:first) || stop]
        end
      else
        breaks
      end
  end

  def segmentation_from_tags(tags)
    breaks = []
    (tags || {}).values.each do |tag|
      breaks += tag.scan(MATCH_TAGS_REGEX).flatten
    end
    breaks.map { |b| parse_break(b) }
  end

  # look for a comma, and use as start of the break and duration
  def parse_break(break_str)
    if break_str.include?(",")
      start_str, duration_str = break_str.split(",", 2).map(&:strip)
      start_time = parse_break_time(start_str)
      if duration_str.to_i > 0
        end_time = start_time + duration_str.to_i
        [start_time, end_time]
      else
        start_time
      end
    else
      [parse_break_time(break_str), nil]
    end
  end

  # parse breaks with either integer milliseconds or hh:mm:ss:ms] format
  def parse_break_time(break_str)
    if break_str.match?(/^\d+$/)
      break_str.to_i
    elsif (match = break_str.match(TIMING_TAG_REGEX))
      hours = match[:hours].to_i
      minutes = match[:minutes].to_i
      seconds = match[:seconds].to_i
      milliseconds = match[:milliseconds].to_i
      (hours * 3600 + minutes * 60 + seconds) * 1000 + milliseconds
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
