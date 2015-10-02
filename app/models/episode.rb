require 'hash_serializer'

class Episode < ActiveRecord::Base
  serialize :overrides, HashSerializer

  belongs_to :podcast
  has_many :tasks, as: :owner

  validates :podcast_id, presence: true
  validates_associated :podcast

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

  def self.create_from_entry!(podcast, entry)
    episode = new(podcast: podcast)
    episode.update_from_entry(entry)
    episode.save!
    episode
  end


  def update_from_entry(entry_resource)
    entry = entry_resource.attributes

    entry_attrs = %w( guid title subtitle description summary content image_url
      explicit keywords categories is_closed_captioned )

    o = entry.slice(*entry_attrs)

    o[:created] = entry[:published]

    o[:audio] = {
      url: entry[:feedburner_orig_enclosure_link] || entry[:enclosure_url],
      type: entry[:enclosure_type],
      size: entry[:enclosure_length],
      duration: entry[:duration]
    }

    o[:link] = entry[:feedburner_orig_link] || entry[:url]

    self.overrides = o

    self
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
      Tasks::CopyAudioTask.create! do |task|
        task.owner = self
      end.start!
    end
  end

  def new_audio_file?
    copy_task = most_recent_copy_task
    copy_task.nil? || copy_task.new_audio_file?
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
    ENV['FEEDER_CDN_HOST']
  end
end
