class EpisodeTimingsImport < EpisodeImport
  COMBINE_TIMINGS_WITHIN = 0.01

  store :config, accessors: [:timings], coder: JSON

  def self.parse_timings(str, strict = false)
    str = str&.strip
    return [] if str.blank?

    # remove any enclosing chars
    if ["()", "[]", "{}"].any? { |c| str.starts_with?(c[0]) && str.ends_with?(c[1]) }
      return parse_timings(str[1...-1])
    end

    # split and parse to floats
    floats = str.split(",").map(&:strip).map do |part|
      part.match(/\A[0-9.]+\z/) && Float(part)
    rescue
      nil
    end

    # must be positive numbers, and IF STRICT at least 1 must have decimal places
    return nil unless floats.all?(&:present?) && floats.all?(&:positive?)
    return nil if strict && floats.all? { |f| f == f.round }

    # sort and combine nearly-equal timings
    floats.sort.each_with_object([]) do |f1, acc|
      acc << f1 unless acc.any? { |f2| f1.between?(f2 - COMBINE_TIMINGS_WITHIN, f2 + COMBINE_TIMINGS_WITHIN) }
    end
  end

  def parse_timings
    self.class.parse_timings(timings)
  end

  def import!
    status_started!

    self.episode = podcast.episodes.find_by_item_guid(guid)
    return status_not_found! unless episode.present?
    return status_bad_timings! if parse_timings.nil?

    # only need to slice if > 0 midroll timings
    if parse_timings.present?
      status_importing!

      # changing audio->uncut medium builds a new Uncut
      episode.medium = "uncut"
      return status_no_media! unless episode.uncut.present?

      episode.uncut.ad_breaks = parse_timings
      return status_bad_timings! unless episode.uncut.valid?

      episode.segment_count = episode.uncut.segmentation.count
      episode.save!

      # slice new contents (if any) and re-copy
      episode.uncut.slice_contents!
      episode.copy_media
    end

    status_complete!
  rescue => err
    status_error!
    raise err
  end
end
