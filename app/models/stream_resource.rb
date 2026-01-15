class StreamResource < ApplicationRecord
  BUFFER_SECONDS = 10

  enum :status, %w[created started recording processing complete invalid short error].to_enum_h, prefix: true

  belongs_to :stream_recording, -> { with_deleted }, touch: true, optional: true
  has_one :podcast, through: :stream_recording
  has_one :record_task, -> { order(id: :desc) }, as: :owner, class_name: "Tasks::RecordStreamTask"
  has_one :copy_task, -> { order(id: :desc) }, as: :owner, class_name: "Tasks::CopyMediaTask"
  has_many :record_tasks, as: :owner, class_name: "Tasks::RecordStreamTask"
  has_many :copy_tasks, as: :owner, class_name: "Tasks::CopyMediaTask"

  validates :start_at, presence: true
  validates :end_at, presence: true, comparison: {greater_than: :start_at}
  validates :actual_start_at, presence: true, if: :done_recording?
  validates :actual_end_at, presence: true, comparison: {greater_than: :actual_start_at}, if: :done_recording?
  validates :original_url, presence: true, if: :done_recording?

  after_initialize :set_defaults
  before_validation :set_defaults

  acts_as_paranoid

  # NOTE: called twice, because podcast won't be there on initialize
  def set_defaults
    set_default(:status, "created")
    set_default(:guid, SecureRandom.uuid)
    set_default(:url, published_url)
  end

  def copy_media(force = false)
    if force || !(status_complete? || copy_task)
      Tasks::CopyMediaTask.create! do |task|
        task.owner = self
      end.start!
    end
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

  # NOTE: for compatibility with copy_media_task.rb
  def medium
    "audio"
  end

  # NOTE: for compatibility with copy_media_task.rb
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
