require 'hash_serializer'

class Episode < ActiveRecord::Base
  serialize :overrides, HashSerializer

  belongs_to :podcast

  has_many :contents, -> { order("position ASC") }
  has_one :enclosure

  validates :podcast_id, presence: true
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

  ENTRY_ATTRS = %w( guid title subtitle description summary content image_url
    explicit keywords categories is_closed_captioned is_perma_link duration ).freeze

  def update_from_entry(entry_resource)
    entry = entry_resource.attributes

    o = entry.slice(*ENTRY_ATTRS)

    o[:published] = Time.parse(entry[:published]) if entry[:published]

    o[:original_enclosure] = entry[:enclosure] || {}
    o[:original_enclosure][:url] ||= entry[:feedburner_orig_enclosure_link]
    o[:link] = entry[:feedburner_orig_link] || entry[:url]

    o[:original_contents] = entry[:contents]

    self.overrides = o

    # TODO: handle updates
    if entry[:enclosure]
      self.enclosure = Enclosure.build_from_enclosure(entry[:enclosure])
    end

    Array(entry[:contents]).each do |c|
      self.contents << Content.build_from_content(c)
    end

    self
  end

  def duration
    overrides[:duration] ||
    (enclosure && enclosure.duration) ||
    contents.inject(0.0) { |s, c| s + c.duration }
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
