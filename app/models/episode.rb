require 'addressable/uri'
require 'addressable/template'
require 'hash_serializer'

class Episode < BaseModel
  serialize :categories, JSON
  serialize :keywords, JSON

  acts_as_paranoid

  serialize :overrides, HashSerializer

  belongs_to :podcast, -> { with_deleted }, touch: true

  has_many :all_contents,
    -> { order('position ASC, created_at DESC') },
    class_name: 'Content',
    autosave: true,
    dependent: :destroy

  has_many :contents,
    -> { order('position ASC, created_at DESC').complete },
    autosave: true,
    dependent: :destroy

  has_many :enclosures,
    -> { order('created_at DESC') },
    autosave: true,
    dependent: :destroy

  validates :podcast_id, :guid, presence: true

  before_validation :initialize_guid, :set_adzerk_keyword

  after_save :publish_updated, if: -> (e) { e.published_at_changed? }

  scope :published, -> { where('published_at IS NOT NULL AND published_at <= now()') }

  def self.by_prx_story(story)
    story_uri = story.links['self'].href
    Episode.with_deleted.find_by(prx_uri: story_uri)
  end

  def publish_updated
    podcast.publish_updated if podcast
  end

  def published?
    !published_at.nil? && published_at <= Time.now
  end

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
    original_guid || "prx_#{podcast.id}_#{guid}"
  end

  def item_guid=(new_guid)
    self.original_guid = new_guid
  end

  def overrides
    self[:overrides] ||= HashWithIndifferentAccess.new
  end

  def categories
    self[:categories] ||= []
  end

  def keywords
    self[:keywords] ||= []
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
    enclosure_url(media.media_url, media.original_url) if media
  end

  def first_media_resource
    contents.blank? ? enclosure : contents.first
  end

  def enclosure_url(base_url, original_url = nil)
    templated_url = enclosure_template_url(base_url, original_url)
    add_enclosure_prefix(templated_url)
  end

  def add_enclosure_prefix(u)
    return u if enclosure_prefix.blank?
    pre = Addressable::URI.parse(enclosure_prefix)
    orig = Addressable::URI.parse(u)
    orig.path = File.join(orig.host, orig.path)
    orig.path = File.join(pre.path, orig.path)
    orig.scheme = pre.scheme
    orig.host = pre.host
    orig.to_s
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
    !(enclosures.blank? && all_contents.blank?)
  end

  def media_ready?
    (!enclosures.blank? && enclosure) ||
    (!all_contents.blank? && all_contents.all?{ |a| a.complete? })
  end

  def enclosure_template
    podcast.enclosure_template
  end

  def enclosure_prefix
    podcast.enclosure_prefix
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

  def set_adzerk_keyword
    return unless published? && adzerk_keyword.nil?
    identifiers = []
    [:title, :published_at, :guid].each do |attr|
      # Adzerk does not allow commas or colons in keywords
      identifiers << self.send(attr).to_s.slice(0, 10).gsub(/[:,]/,'')
    end
    self.adzerk_keyword = identifiers.join('_')
  end
end
