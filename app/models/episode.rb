require 'hash_serializer'

class Episode < ActiveRecord::Base
  serialize :overrides, HashSerializer

  belongs_to :podcast

  has_many :contents, -> { order("position ASC") }
  has_one :enclosure

  validates :podcast_id, :guid, presence: true
  validates_associated :podcast

  acts_as_paranoid

  before_validation :initialize_guid

  def initialize_guid
    guid
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def item_guid
    original_guid || "prx:#{podcast.path}:#{guid}"
  end

  def overrides
    self[:overrides] ||= HashWithIndifferentAccess.new
  end

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

  ENTRY_ATTRS = %w( title subtitle description summary content image_url
    explicit keywords categories is_closed_captioned is_perma_link duration ).freeze

  def update_from_entry(entry_resource)
    entry = entry_resource.attributes

    self.original_guid = entry[:guid]

    o = entry.slice(*ENTRY_ATTRS).with_indifferent_access
    o[:published] = Time.parse(entry[:published]) if entry[:published]
    o[:link] = entry[:feedburner_orig_link] || entry[:url]
    o[:original_enclosure] = entry[:enclosure] || {}
    o[:original_enclosure][:url] = entry[:feedburner_orig_enclosure_link] || o[:original_enclosure][:url]
    o[:original_contents] = entry[:contents]
    self.overrides = overrides.merge(o)

    update_enclosure

    update_contents

    self
  end

  def update_contents
    Array(overrides[:original_contents]).each_with_index do |c, i|
      existing_content = contents[i]
      if existing_content && existing_content.original_url != c[:url]
        existing_content.destroy
        existing_content = nil
      end
      if !existing_content
        new_content = Content.build_from_content(c)
        contents << new_content
        new_content.set_list_position(i + 1)
      end
    end
  end

  def update_enclosure
    enclosure_url = overrides[:original_enclosure][:url]
    if !enclosure_url || (enclosure && (enclosure.original_url != enclosure_url))
      enclosure.try(:destroy)
      self.enclosure = nil
    end
    self.enclosure ||= Enclosure.build_from_enclosure(overrides[:original_enclosure])
  end

  def enclosure_info
    return nil unless audio_ready?
    {
      url: audio_url,
      type: content_type,
      size: file_size,
      duration: duration.to_i
    }
  end

  def audio_url
    enclosure.try(:audio_url) || "#{base_published_url}/audio.mp3"
  end

  def content_type
    enclosure.try(:mime_type) || contents.first.try(:mime_type)
  end

  def duration
    overrides[:duration] ||
    (enclosure && enclosure.duration) ||
    contents.inject(0.0) { |s, c| s + c.duration }
  end

  def file_size
    (enclosure && enclosure.file_size) ||
    contents.inject(0) { |s, c| s + c.file_size }
  end

  def update_from_story!(story)
    touch
  end

  def set_guid
    self.guid ||= SecureRandom.uuid
  end

  def copy_audio(force = false)
    enclosure.copy_audio if enclosure
    contents.each{ |c| c.copy_audio }
  end

  def base_published_url
    "#{podcast.base_published_url}/#{guid}"
  end

  def include_in_feed?
    audio_ready?
  end

  def audio_ready?
    (!enclosure.blank? && enclosure.complete?) ||
    (!contents.blank? && contents.all?{ |a| a.complete? })
  end

  def enclosure_template
    podcast.enclosure_template
  end

  def podcast_slug
    podcast.path
  end

  def audio_files
    if !contents.blank?
      contents
    else
      Array(enclosure)
    end
  end

  def published
    created_at
  end
end
