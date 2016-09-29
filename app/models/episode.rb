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
  has_many :all_contents, -> { order("position ASC, created_at DESC") }, class_name: 'Content'
  has_many :contents, -> { order("position ASC, created_at DESC").complete }
  has_many :enclosures, -> { order("created_at DESC") }

  validates :podcast_id, :guid, presence: true
  validates_associated :podcast

  before_validation :initialize_guid

  scope :released, -> { where('released_at IS NULL OR released_at <= now()') }

  def enclosure
    enclosures.complete.first
  end

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
    published = story.attributes[:published_at]
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
    with_lock do
      entry = entry_resource.attributes

      o = entry.slice(*ENTRY_ATTRIBUTES).with_indifferent_access
      self.overrides = overrides.merge(o)

      self.original_guid = overrides[:guid]
      update_published_at
      update_enclosure
      update_contents

      # must come after update_enclosure and update_contents
      # as it depends on media_url
      update_link
    end
    self
  end

  def update_published_at
    published = overrides[:published] || overrides[:last_modified]
    self.published_at = Time.parse(published) if published
  end

  # must be called after update_enclosure and update_contents
  # as it depends on media_url
  def update_link
    overrides[:link] = overrides[:feedburner_orig_link] || overrides[:url]

    # libsyn sets the link to a libsyn url, instead set to media file or page
    if overrides[:link].match(/libsyn\.com/)
      overrides[:link] = media_url
    end
  end

  def update_enclosure
    enclosure_hash = overrides.fetch(:enclosure, {}).dup
    if overrides[:feedburner_orig_enclosure_link]
      enclosure_hash[:url] = overrides[:feedburner_orig_enclosure_link]
    end

    # If the enclosure has been removed, just delete it (rare but simple case)
    if !overrides[:enclosure]
      enclosure.try(:destroy)
    end

    # If no enclosure exists for this url (of any status), create one
    if overrides[:enclosure] && !enclosures.exists?(original_url: enclosure_hash[:url])
      self.enclosures << Enclosure.build_from_enclosure(self, enclosure_hash)
    end
  end

  def update_contents
    if overrides[:contents].blank?
      contents.destroy_all
      return
    end

    # If there really are too many files now, truncate the excess
    if contents.size > overrides[:contents].size
      all_contents.destroy(contents[overrides[:contents].size..(contents.size - 1)])
    end

    Array(overrides[:contents]).each_with_index do |c, i|
      existing_content = all_contents.where(position: (i + 1), original_url: c[:url]).first

      # If there is an existing file with the same url, update
      if existing_content
        existing_content.update_with_content!(c)

      # Otherwise, make a new content to be or replace content for that position
      # If there is no file, or the file has a different url
      else
        new_content = Content.build_from_content(self, c)
        new_content.position = i + 1
        self.all_contents << new_content
      end
    end
  end

  def enclosure_info
    return nil unless media_ready?
    {
      url: media_url,
      type: content_type,
      size: file_size,
      duration: duration.to_i
    }
  end

  def media_url
    media = first_media_resource
    enclosure_template_url(media.media_url, media.original_url) if media
  end

  def first_media_resource
    contents.blank? ? enclosure : contents.first
  end

  def enclosure_template_url(base_url, original_url = nil)
    return base_url if enclosure_template.blank?

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
    first_media_resource.try(:mime_type) || 'application/octet-stream'
  end

  def duration
    if contents.blank?
      enclosure.try(:duration).to_f
    else
      contents.inject(0.0) { |s, c| s + c.duration.to_f }
    end + podcast.duration_padding.to_f
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

  def copy_media(force = false)
    enclosures.each { |e| e.copy_media(force) }
    all_contents.each { |c| c.copy_media(force) }
  end

  def base_published_url
    "#{podcast.base_published_url}/#{guid}"
  end

  def include_in_feed?
    !has_media? || media_ready?
  end

  def has_media?
    enclosures.size > 0 || contents.size > 0
  end

  def media_ready?
    (!enclosure.blank? && enclosure.complete?) ||
    (!contents.blank? && contents.all?{ |a| a.complete? })
  end

  def enclosure_template
    podcast.enclosure_template
  end

  def podcast_slug
    podcast.path
  end

  def media_files
    if !contents.blank?
      contents
    else
      Array(enclosure)
    end
  end

  def audio_files
    media_files
  end
end
