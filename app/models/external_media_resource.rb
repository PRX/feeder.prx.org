class ExternalMediaResource < MediaResource
  validates :duration, numericality: {greater_than: 0}, if: :status_complete?

  def guid
    nil
  end

  def url
    original_url
  end

  def media_url
    original_url
  end

  def copy_media(force = false)
    analyze_media(force)
  end

  def analyze_media(force = false)
    if force || !(status_complete? || task)
      Tasks::AnalyzeMediaTask.create! do |task|
        task.owner = self
      end.start!
    end
  end
end
