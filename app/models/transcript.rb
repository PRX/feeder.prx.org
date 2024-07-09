class Transcript < ApplicationRecord
  acts_as_paranoid

  belongs_to :episode

  has_one :task, -> { order("id desc") }, as: :owner
  has_many :tasks, as: :owner

  def published_url
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
    self.status = :created
  end

  def copy_transcript(force = false)
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
      copy_transcript(true)
    end
  end

  def _retry=(_val)
    retry!
  end
end
