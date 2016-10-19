require 'addressable/uri'
require 'addressable/template'
require 'hash_serializer'

class Episode < ActiveRecord::Base
  serialize :categories, JSON
  serialize :keywords, JSON

  ENTRY_ATTRIBUTES = %w(author block categories content description explicit
    feedburner_orig_enclosure_link feedburner_orig_link image_url is_closed_captioned
    is_perma_link keywords position subtitle summary title url).freeze

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

  def author=(a)
    author = a || {}
    self.author_name = author['name']
    self.author_email = author['email']
  end

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

    # Add in a bunch more stuff getting saved here

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
      self.overrides = entry_resource.attributes.with_indifferent_access
      o = overrides.slice(*ENTRY_ATTRIBUTES).with_indifferent_access
      self.assign_attributes(o)

      update_guid
      update_dates
      update_enclosure
      update_contents
      # must come after update_enclosure & update_contents, depends on media_url
      update_link
    end
    self
  end

  def update_guid
    self.original_guid = overrides[:guid]
  end

  def update_dates
    self.published = Time.parse(overrides[:published]) if overrides[:published]
    self.updated = Time.parse(overrides[:updated]) if overrides[:updated]
    self.published_at = published || updated
  end

  # must be called after update_enclosure and update_contents
  # as it depends on media_url
  def update_link
    self.url = overrides[:feedburner_orig_link] || overrides[:url]
    # libsyn sets the link to a libsyn url, instead set to media file or page
    self.url = media_url if url.match(/libsyn\.com/)
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
    first_media_resource.try(:mime_type) || 'audio/mpeg'
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
