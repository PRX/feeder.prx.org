class StreamResource < ApplicationRecord
  BUFFER_SECONDS = 10

  enum :status, %w[created started recording processing complete invalid short error].to_enum_h, prefix: true

  belongs_to :stream_recording, -> { with_deleted }, touch: true, optional: true
  has_one :podcast, through: :stream_recording
  has_one :task, -> { order(id: :desc) }, as: :owner
  has_many :tasks, as: :owner

  validates :start_at, presence: true
  validates :end_at, presence: true, comparison: {greater_than: :start_at}
  validates :actual_start_at, presence: true, if: :done_recording?
  validates :actual_end_at, presence: true, comparison: {greater_than: :actual_start_at}, if: :done_recording?
  validates :original_url, presence: true, if: :done_recording?

  after_initialize :set_defaults
  before_validation :set_defaults

  acts_as_paranoid

  # find/build for a specific oxbow job_id
  # <podcast_id>/<stream_recording_id>/<start_time>/<end_time>/<guid>.mp3
  def self.decode(str)
    parts = str.split("/")
    podcast_id = parts[0].to_i
    recording_id = parts[1].to_i
    start_at =
      begin
        parts[2]&.to_time
      rescue
        nil
      end
    end_at =
      begin
        parts[3]&.to_time
      rescue
        nil
      end
    return unless podcast_id > 0 && recording_id > 0 && start_at && end_at

    rec = StreamRecording.find_by_id(recording_id)
    return unless rec

    res = rec.stream_resources.find_by(start_at: start_at, end_at: end_at)
    return res if res

    rec.stream_resources.build(start_at: start_at, end_at: end_at)
  end

  # NOTE: called twice, because podcast won't be there on initialize
  def set_defaults
    set_default(:status, "created")
    set_default(:guid, SecureRandom.uuid)
    set_default(:url, published_url)
  end

  def copy_media(force = false)
    # TODO
  end

  def done_recording?
    %w[created started recording].exclude?(status)
  end

  def file_name
    File.basename(URI.parse(original_url).path) if original_url.present?
  end

  def path
    "#{podcast.path}/#{stream_resource_path}" if podcast
  end

  def published_url
    "#{podcast.base_published_url}/#{stream_resource_path}" if podcast
  end

  def url
    self[:url] ||= published_url
  end

  def href
    (status_complete? || status_invalid?) ? url : original_url
  end

  def medium
    "audio"
  end

  def medium=(val)
    medium
  end

  def waveform_url
    "#{url}.json"
  end

  def waveform_path
    "#{path}.json"
  end

  def waveform_file_name
    "#{file_name}.json"
  end

  def generate_waveform?
    true
  end

  def slice?
    false
  end

  def missing_seconds
    return unless start_at && end_at

    if actual_start_at.nil? || actual_end_at.nil?
      end_at - start_at
    else
      missing_start = [actual_start_at - start_at, 0].max
      missing_end = [end_at - actual_end_at, 0].max
      missing_start + missing_end
    end
  end

  private

  def stream_resource_path
    "streams/#{guid}/#{file_name}"
  end
end
