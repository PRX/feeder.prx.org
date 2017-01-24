class MediaResource < BaseModel
  has_one :task, as: :owner
  belongs_to :episode, -> { with_deleted }, touch: true

  enum status: [ :started, :created, :processing, :complete, :error, :retrying, :cancelled ]

  before_validation :initialize_guid_and_url

  def initialize_guid_and_url
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
    if self.original_url != h
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
    ext = File.extname(original_url || '')
    ext = '.mp3' if ext.blank?
    "#{episode.base_published_url}/#{guid}#{ext}" if episode
  end

  def update_from_fixer(fixer_task)
    if info = fixer_task.fetch('task', {}).fetch('result_details', {}).fetch('info', nil)
      update_attributes_with_fixer_info(info).save
    end
  end

  def update_attributes_with_fixer_info(info)
    update_mime_type_with_fixer_info(info)
    self.medium = self.mime_type.split('/').first
    self.file_size = info['size'].to_i
    self.sample_rate = info['sample_rate'].to_i
    self.channels = info['channels'].to_i
    self.duration = info['length'].to_f
    self.bit_rate = info['bit_rate'].to_i
    self
  end

  def update_mime_type_with_fixer_info(info)
    if info['content_type'].nil? || info['content_type'] == 'application/octect-stream'
      self.mime_type ||= 'audio/mpeg'
    else
      self.mime_type = info['content_type']
    end
  end
end
