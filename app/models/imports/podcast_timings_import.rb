require "csv"

class PodcastTimingsImport < PodcastImport
  SAMPLE_ROWS = 10
  SAMPLE_PERCENT = 0.50

  store :config, accessors: [:file_name, :timings, :guid_index, :timings_index, :has_header], coder: JSON

  has_many :episode_imports, dependent: :destroy, class_name: "EpisodeTimingsImport", foreign_key: :podcast_import_id

  validate :validate_timings, if: :timings_changed?

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

    # check if the first row looks like a header and set the count
    self.has_header = !has_episode_with_guid?(csv.first[guid_index].strip)
    self.feed_episode_count = has_header ? csv.count - 1 : csv.count
  end

  def import!
    status_started!

    # cleanup existing dups - they may be recreated later
    episode_imports.status_duplicate.destroy_all

    guids = []
    rows = has_header ? csv[1..] : csv

    rows.each do |row|
      guid = row[guid_index]
      timings = row[timings_index]

      # mark dups with a completed episode import
      if guids.include?(guid)
        episode_imports.create!(guid: guid, timings: timings, status: :duplicate)
      else
        guids << guid
        ei = episode_imports.not_status_duplicate.find_by_guid(guid) || episode_imports.build
        ei.guid = guid
        ei.timings = timings
        ei.save!
        ei.import_later
      end
    end

    status_importing!
  rescue => err
    status_error!
    raise err
  end

  protected

  def parse_csv
    if timings.present?
      if timings.include?("\t")
        CSV.parse(timings, col_sep: "\t", row_sep: :auto, skip_blanks: true, liberal_parsing: true)
      else
        CSV.parse(timings, col_sep: ",", row_sep: :auto, skip_blanks: true, liberal_parsing: true)
      end
    end
  rescue
    nil
  end

  def find_guid_index(row)
    row.find_index do |val|
      true if has_episode_with_guid?(val&.strip)
    end
  end

  # look for non-blank values that can be parsed to a timings array
  def find_timings_index(row)
    row.find_index do |val|
      if val&.strip&.present?
        !EpisodeTimingsImport.parse_timings(val).nil?
      end
    end
  end
end
