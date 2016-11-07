require 'addressable/uri'
require 'addressable/template'
require 'hash_serializer'

class Episode < ActiveRecord::Base
  serialize :categories, JSON
  serialize :keywords, JSON

  acts_as_paranoid

  serialize :overrides, HashSerializer

  belongs_to :podcast, -> { with_deleted }
  has_many :all_contents, -> { order('position ASC, created_at DESC') }, class_name: 'Content'
  has_many :contents, -> { order('position ASC, created_at DESC').complete }
  has_many :enclosures, -> { order('created_at DESC') }

  validates :podcast_id, :guid, presence: true
  # validates_associated :podcast

  before_validation :initialize_guid

  scope :released, -> { where('released_at IS NULL OR released_at <= now()') }
  scope :published, -> { where('published_at IS NOT NULL') }

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

  def copy_media(force = false)
    enclosures.each { |e| e.copy_media(force) }
    all_contents.each { |c| c.copy_media(force) }
  end

  def base_published_url
    "#{podcast.base_published_url}/#{guid}"
  end

  def include_in_feed?
    !media? || media_ready?
  end

  def media?
    media_files.size > 0
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
