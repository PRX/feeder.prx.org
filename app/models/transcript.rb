class Transcript < ApplicationRecord
  acts_as_paranoid

  belongs_to :episode

  has_one :task, -> { order("id desc") }, as: :owner
  has_many :tasks, as: :owner

  before_validation :initialize_attributes, on: :create

  validates :original_url, presence: true

  validates :mime_type, inclusion: {in: %w[text/plain application/json]}, if: :status_complete?, allow_blank: true

  enum :status, [:started, :created, :processing, :complete, :error, :retrying, :cancelled, :invalid], prefix: true

  def published_url
    "#{episode.base_published_url}/#{transcript_path}"
  end

  def transcript_path
    "transcripts/#{guid}/#{file_name}"
  end

  def initialize_attributes
    self.status ||= :created
    guid
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def file_name
    if original_url.present?
      File.basename(URI.parse(original_url).path)
    end
  end

  def url
    self[:url] ||= published_url
  end

  def path
    URI.parse(url).path.sub(/\A\//, "") if url.present?
  end

  def href
    (status_complete? || status_invalid?) ? url : original_url
  end

  def href=(h)
    if original_url != h
      self.original_url = h
    end
    original_url
  end

  def original_url=(url)
    super
    if original_url_changed?
      reset_transcript_attributes
    end
    self[:original_url]
  end

  def reset_transcript_attributes
    self.format = nil
    self.mime_type = nil
    self.file_size = nil
    self.status = :created
  end

  def copy_media(force = false)
    if force || !(status_complete? || task)
      Tasks::CopyTranscriptTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def retryable?
    if %w[started created processing retrying].include?(status)
      last_event = task&.updated_at || updated_at || Time.now
      Time.now - last_event > 100
    else
      status_error?
    end
  end

  def retry!
    if retryable?
      status_retrying!
      copy_media(true)
    end
  end

  def _retry=(_val)
    retry!
  end
end
