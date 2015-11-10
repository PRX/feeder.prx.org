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
    self[:url] ||= (episode && published_audio_url)
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

  def published_audio_url
    "#{episode.base_published_url}/#{guid}.mp3" if episode
  end
end
