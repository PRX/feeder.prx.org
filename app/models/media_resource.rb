class MediaResource < ActiveRecord::Base
  has_one :task, as: :owner
  belongs_to :episode

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
    self[:url] ||= (episode && audio_url)
    self[:url]
  end

  def copy_audio
    Tasks::CopyAudioTask.create! do |task|
      task.owner = self
    end.start!
  end

  def is_processed?
    complete?
  end

  def audio_url
    "#{episode.base_published_url}/#{guid}.mp3" if episode
  end

  def update_from_fixer(fixer_task)
    if audio_info = fixer_task.fetch(:task, {}).fetch(:result_details, {}).fetch(:info, nil)
      update_attributes_with_fixer_info(audio_info).save
    end
  end

  def update_attributes_with_fixer_info(audio_info)
    self.mime_type = audio_info[:content_type]
    self.file_size = audio_info[:size].to_i
    self.medium = self.mime_type.split('/').first
    self.sample_rate = audio_info[:sample_rate].to_i
    self.channels = audio_info[:channels].to_i
    self.duration = audio_info[:length].to_f
    self.bit_rate = audio_info[:bit_rate].to_i
    self
  end
end
