class ExternalMediaResource < MediaResource
  validates :duration, numericality: {greater_than: 0}, if: :status_complete?
  after_create_commit :analyze_media

  def guid
    self[:guid]
  end

  def url
    original_url
  end

  def media_url
    original_url
  end

  def copy_media(force = false)
  end

  def analyze_media(force = false)
    if force || !(status_complete? || task)
      Tasks::AnalyzeMediaTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def retry!
    if retryable?
      status_retrying!
      analyze_media(true)
    end
  end
end
