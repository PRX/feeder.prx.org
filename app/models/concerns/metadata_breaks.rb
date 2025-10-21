module MetadataBreaks
  extend ActiveSupport::Concern

  MATCH_TAGS = "AIS_AD_BREAK_"
  MATCH_TAGS_REGEX = /#{MATCH_TAGS}[^=]+=([^;]+)/
  TIMING_TAG_REGEX = /^(?<hours>\d+):(?<minutes>\d+):(?<seconds>\d+)(?::(?<milliseconds>\d+))?$/

  def breaks_from_tags(tags)
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
end
