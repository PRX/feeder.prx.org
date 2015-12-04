require 'addressable/uri'
require 'addressable/template'
require 'hash_serializer'

class Episode < ActiveRecord::Base
  ENTRY_ATTRIBUTES = %w(title subtitle description summary content is_perma_link
    image_url explicit keywords categories is_closed_captioned duration contents
    guid enclosure feedburner_orig_enclosure_link feedburner_orig_link published
    url last_modified ).freeze

  acts_as_paranoid

  serialize :overrides, HashSerializer

  belongs_to :podcast, -> { with_deleted }
  has_many :contents, -> { order("position ASC") }
  has_one :enclosure

  validates :podcast_id, :guid, presence: true
  validates_associated :podcast

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
    published = story.attributes[:publishedAt]
    published = Time.parse(published) if published
    create!(podcast: podcast, prx_uri: story_uri, published_at: published)
  end

  def self.create_from_entry!(podcast, entry)
    episode = new(podcast: podcast)
    episode.update_from_entry(entry)
    episode.save!
    episode
  end

  def update_from_entry(entry_resource)
    entry = entry_resource.attributes

    o = entry.slice(*ENTRY_ATTRIBUTES).with_indifferent_access
    self.overrides = overrides.merge(o)

    self.original_guid = overrides[:guid]
    update_published_at
    update_enclosure
    update_contents

    # must come after update_enclosure and update_contents
    # as it depends on audio url
    update_link
    self
  end

  def update_published_at
    published = overrides[:published] || overrides[:last_modified]
    self.published_at = Time.parse(published) if published
  end

  # must be called after update_enclosure and update_contents
  # as it depends on audio url
  def update_link
    overrides[:link] = overrides[:feedburner_orig_link] || overrides[:url]

    # libsyn sets the link to a libsyn url - audio file or page
    if overrides[:link].match(/libsyn\.com/)
      overrides[:link] = audio_url
    end
  end

  def update_enclosure
    enclosure_hash = overrides.fetch(:enclosure, {}).dup
    if overrides[:feedburner_orig_enclosure_link]
      enclosure_hash[:url] = overrides[:feedburner_orig_enclosure_link]
    end
    if !overrides[:enclosure] || (enclosure && (enclosure.original_url != enclosure_hash[:url]))
      enclosure.try(:destroy)
      self.enclosure = nil
    end
    if enclosure_hash[:url]
      self.enclosure ||= Enclosure.build_from_enclosure(self, enclosure_hash)
    end
  end

  def update_contents
    Array(overrides[:contents]).each_with_index do |c, i|
      existing_content = contents[i]
      if existing_content && existing_content.original_url != c[:url]
        existing_content.destroy
        existing_content = nil
      end
      if !existing_content
        new_content = Content.build_from_content(self, c)
        contents << new_content
        new_content.set_list_position(i + 1)
      end
    end
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
    audio = first_audio_resource
    enclosure_template_url(audio.audio_url, audio.original_url) if audio
  end

  def first_audio_resource
    if contents.blank?
      enclosure
    else
      contents.first
    end
  end

  def enclosure_template_url(base_url, original_url = nil)
    return base_url if enclosure_template.blank?
    return base_url if content_type.split('/').first != 'audio'

    expansions = enclosure_template_expansions(base_url, original_url)
    template = Addressable::Template.new(enclosure_template)
    template.expand(expansions).to_str
  end

  def enclosure_template_expansions(base_url, original_url)
    original = Addressable::URI.parse(original_url || '').to_hash
    original = Hash[original.map { |k,v| ["original_#{k}".to_sym, v] }]
    base = Addressable::URI.parse(base_url || '').to_hash
    {
      original_filename: File.basename(original[:original_path].to_s),
      original_extension: File.extname(original[:original_path].to_s),
      filename: File.basename(base[:path].to_s),
      extension: File.extname(base[:path].to_s),
      slug: podcast_slug,
      guid: guid
    }.merge(original).merge(base)
  end

  def content_type
    first_audio_resource.try(:mime_type) || ''
  end

  def duration
    if contents.blank?
      enclosure.try(:duration).to_f
    else
      contents.inject(0.0) { |s, c| s + c.duration.to_f }
    end
  end

  def file_size
    if contents.blank?
      enclosure.try(:file_size)
    else
      contents.inject(0) { |s, c| s + c.file_size.to_i }
    end
  end

  def update_from_story!(story)
    touch
  end

  def copy_audio(force = false)
    enclosure.copy_audio(force) if enclosure
    contents.each{ |c| c.copy_audio(force) }
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
end
