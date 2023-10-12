require "csv"

class PodcastTimingsImport < PodcastImport
  SAMPLE_ROWS = 10
  SAMPLE_PERCENT = 0.50

  store :config, accessors: [:file_name, :timings, :guid_index, :timings_index, :has_header], coder: JSON

  has_many :episode_imports, dependent: :destroy, class_name: "EpisodeTimingsImport", foreign_key: :podcast_import_id

  validate :validate_timings, if: :timings_changed?

  def set_defaults
    super
  end

  def timings=(val)
    @csv = nil
    super(val)
  end

  def csv
    @csv ||= parse_csv
  end

  def csv=(val)
    self.timings = val.try(:map, &:to_csv)&.join
    @csv = val
  end

  def default_guid_length
    Episode.generate_item_guid(podcast_id, SecureRandom.uuid).length
  end

  def minimum_guid_length
    @minimum_guid_length ||= [podcast&.episodes&.minimum("length(original_guid)"), default_guid_length].compact.min
  end

  def maximum_guid_length
    @maximum_guid_length ||= [podcast&.episodes&.minimum("length(original_guid)"), default_guid_length].compact.max
  end

  def has_episode_with_guid?(guid)
    if guid.blank? || guid.length < minimum_guid_length || guid.length > maximum_guid_length
      false
    else
      podcast&.episodes&.find_by_item_guid(guid) || false
    end
  end

  def validate_timings
    return errors.add(:timings, :blank) if timings.blank?
    return errors.add(:timings, :not_csv) if csv.blank? || csv[0].count < 2

    # sample to find guid column
    sample_rows = csv.first(SAMPLE_ROWS)
    sample_guids = sample_rows.map { |row| find_guid_index(row) }.compact
    if sample_guids.uniq.count == 1 && sample_guids.count >= (sample_rows.count * SAMPLE_PERCENT).floor
      self.guid_index = sample_guids.uniq.first
    else
      return errors.add(:timings, :guid_not_found)
    end

    # sample to find timings column
    sample_timings = sample_rows.map { |r| find_timings_index(r) }.compact
    if sample_timings.uniq.count == 1 && sample_timings.count >= (sample_rows.count * SAMPLE_PERCENT).floor
      self.timings_index = sample_timings.uniq.first
    else
      return errors.add(:timings, :timings_not_found)
    end

    # check if the first row looks like a header
    self.has_header = !has_episode_with_guid?(csv.first[guid_index].strip)
  end

  protected

  def parse_csv
    if timings.present?
      if timings.include?("\t")
        CSV.parse(timings, col_sep: "\t", row_sep: :auto, skip_blanks: true)
      else
        CSV.parse(timings, col_sep: ",", row_sep: :auto, skip_blanks: true)
      end
    end
  rescue
    nil
  end

  def find_guid_index(row)
    row.find_index do |val|
      true if has_episode_with_guid?(val.strip)
    end
  end

  def find_timings_index(row)
    row.find_index do |val|
      if val.strip == "{}"
        true
      elsif val.starts_with?("{") && val.ends_with?("}")
        all_floats?(val[1...-1])
      elsif val.present?
        all_floats?(val)
      end
    end
  end

  def all_floats?(str)
    floats = str.split(",").map(&:strip).map do |part|
      part.match(/\A[0-9.]+\z/) && Float(part)
    rescue
      nil
    end

    # all must be numbers, > 0 must be decimals
    floats.all?(&:present?) && floats.any? { |f| f != f.round }
  end
end
