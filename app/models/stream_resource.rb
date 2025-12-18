class StreamResource < ApplicationRecord
  BUFFER_SECONDS = 10

  enum :status, %w[started created processing complete error retrying cancelled invalid].to_enum_h, prefix: true

  belongs_to :stream_recording, -> { with_deleted }, touch: true, optional: true
  has_one :podcast, through: :stream_recording
  has_one :task, -> { order(id: :desc) }, as: :owner
  has_many :tasks, as: :owner

  validates :start_at, presence: true
  validates :end_at, presence: true, comparison: {greater_than: :start_at}
  validates :actual_start_at, presence: true
  validates :actual_end_at, presence: true, comparison: {greater_than: :actual_start_at}
  validates :original_url, presence: true

  after_initialize :set_defaults
  before_validation :set_defaults

  acts_as_paranoid

  # NOTE: called twice, because podcast won't be there on initialize
  def set_defaults
    set_default(:status, "created")
    set_default(:guid, SecureRandom.uuid)
    set_default(:url, published_url)
  end

  def file_name
    File.basename(URI.parse(original_url).path) if original_url.present?
  end

  def published_path
    "#{podcast.path}/#{stream_resource_path}" if podcast
  end

  def published_url
    "#{podcast.base_published_url}/#{stream_resource_path}" if podcast
  end

  private

  def stream_resource_path
    "streams/#{guid}/#{file_name}"
  end
end
