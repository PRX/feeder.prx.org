class Episode < ActiveRecord::Base
  include PrxAccess

  serialize :overrides, JSON

  belongs_to :podcast
  has_many :tasks, as: :owner

  validates :podcast, presence: true

  acts_as_paranoid

  before_save :set_guid

  def self.by_prx_story(story_uri)
    Episode.with_deleted.where(prx_uri: story_uri).first
  end

  def set_guid
    self.guid ||= SecureRandom.uuid
  end

  def story_id
    prx_uri
  end

  def copy_audio(force = false)
    # see if the audio uri has been updated (new audio file in the story)
    if force || new_audio_file?
      copy_task = Tasks::CopyAudioTask.create!(owner: self)
      copy_task.start!
    end
  end

  def new_audio_file?
    most_recent_copy_task.try(:new_audio_file?)
  end

  def include_in_feed?
    audio_ready?
  end

  def audio_ready?
    copy_task = most_recent_copy_task
    copy_task && copy_task.complete?
  end

  def most_recent_copy_task
    tasks.copy_audio.order('created_at desc').first
  end
end
