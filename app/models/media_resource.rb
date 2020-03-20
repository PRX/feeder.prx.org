class MediaResource < BaseModel
  has_one :task, as: :owner
  belongs_to :episode, -> { with_deleted }, touch: true

  enum status: [ :started, :created, :processing, :complete, :error, :retrying, :cancelled ]

  before_validation :initialize_attributes, on: :create

  def initialize_attributes
    self.status ||= :created
    guid
    url
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def url
    self[:url] ||= media_url
  end

  def href
    complete? ? url : original_url
  end

  def href=(h)
    if original_url != h
      self.original_url = h
      self.task = nil
      self.status = nil
    end
    original_url
  end

  def copy_media(force = false)
    if !task || force
      Tasks::CopyMediaTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def media_url
    media_url_for_base(episode.base_published_url) if episode
  end

  def media_url_for_base(base_published_url)
    ext = File.extname(original_url || '')
    ext = '.mp3' if ext.blank?
    "#{base_published_url}/#{guid}#{ext}"
  end

end
