class MediaResource < ActiveRecord::Base
  has_one :task, as: :owner
  belongs_to :episode, -> { with_deleted }

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
    self[:url]
  end

  def copy_media(force = false)
    if !task || force
      Tasks::CopyMediaTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def is_processed?
    complete?
  end

  def media_url
    "#{episode.base_published_url}/#{guid}.mp3" if episode
  end

  def update_from_fixer(fixer_task)
    if info = fixer_task.fetch('task', {}).fetch('result_details', {}).fetch('info', nil)
      update_attributes_with_fixer_info(info).save
    end
  end

  def update_attributes_with_fixer_info(info)
    self.mime_type = info['content_type']
    self.file_size = info['size'].to_i
    self.medium = self.mime_type.split('/').first
    self.sample_rate = info['sample_rate'].to_i
    self.channels = info['channels'].to_i
    self.duration = info['length'].to_f
    self.bit_rate = info['bit_rate'].to_i
    self
  end
end
