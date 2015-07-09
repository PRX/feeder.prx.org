require 'hash_serializer'

class Episode < ActiveRecord::Base
  serialize :overrides, HashSerializer

  belongs_to :podcast
  has_many :tasks, as: :owner

  validates :podcast, presence: true

  acts_as_paranoid

  before_save :set_guid

  def self.by_prx_story(story)
    story_uri = story.links['self'].href
    Episode.with_deleted.find_by(prx_uri: story_uri)
  end

  def self.create_from_story!(story)
    series_uri = story.links['series'].href
    story_uri = story.links['self'].href
    podcast = Podcast.find_by!(prx_uri: series_uri)
    create!(podcast: podcast, prx_uri: story_uri)
  end

  def update_from_story!(story)
    touch
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

  def enclosure_info
    info = most_recent_copy_task.audio_info
    {
      url: audio_url,
      type: info[:content_type],
      size: info[:size],
      duration: info[:length].to_i
    }
  end

  def audio_url
    dest = most_recent_copy_task.options[:destination]
    s3_uri = URI.parse(dest)
    "http://#{feeder_cdn_host}#{s3_uri.path}"
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

  # todo: make this per podcast
  def feeder_cdn_host
    ENV['FEEDER_CDN_HOST'] ||
      (Rails.env.production? ? '' : (Rails.env + '-')) + 'f.prxu.org'
  end
end
