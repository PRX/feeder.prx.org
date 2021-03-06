require 'addressable/uri'
require 'addressable/template'
require 'hash_serializer'
require 'text_sanitizer'

class Episode < BaseModel
  include TextSanitizer

  serialize :categories, JSON
  serialize :keywords, JSON

  acts_as_paranoid

  serialize :overrides, HashSerializer

  belongs_to :podcast, -> { with_deleted }, touch: true

  has_many :images,
           -> { order('created_at DESC') },
           class_name: 'EpisodeImage', autosave: true, dependent: :destroy

  has_many :all_contents,
           -> { order('position ASC, created_at DESC') },
           class_name: 'Content', autosave: true, dependent: :destroy

  has_many :contents,
           -> { order('position ASC, created_at DESC').complete },
           autosave: true, dependent: :destroy

  has_many :enclosures,
           -> { order('created_at DESC') },
           autosave: true, dependent: :destroy

  validates :podcast_id, :guid, presence: true
  validates :itunes_type, inclusion: { in: %w[full trailer bonus] }
  validates :episode_number,
            numericality: { only_integer: true }, allow_nil: true
  validates :season_number,
            numericality: { only_integer: true }, allow_nil: true
  validates :explicit, inclusion: { in: %w[true false] }, allow_nil: true

  before_validation :initialize_guid, :set_external_keyword, :sanitize_text

  after_save :publish_updated, if: ->(e) { e.published_at_changed? }

  scope :published,
        -> { where('published_at IS NOT NULL AND published_at <= now()') }

  alias_attribute :number, :episode_number
  alias_attribute :season, :season_number

  def self.release_episodes!(options = {})
    podcasts = []
    episodes_to_release.each do |e|
      podcasts << e.podcast
      e.touch
    end
    podcasts.uniq.each { |p| p.publish_updated && p.publish! }
  end

  def self.episodes_to_release
    where('published_at > updated_at AND published_at <= now()').all
  end

  def self.by_prx_story(story)
    Episode.find_by(prx_uri: story_uri(story))
  end

  def self.story_uri(story)
    (story.links['self'].href || '').gsub('/authorization/', '/')
  end

  def publish_updated
    podcast.publish_updated if podcast
  end

  def published?
    !published_at.nil? && published_at <= Time.now
  end

  def draft?
    published_at.nil?
  end

  def was_draft?
    published_at_changed? ? published_at_was.nil? : draft?
  end

  def author=(a)
    author = a || {}
    self.author_name = author['name']
    self.author_email = author['email']
  end

  def enclosure
    enclosures.complete.first
  end

  def image
    images.complete.first
  end

  def initialize_guid
    guid
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def explicit=(value)
    super(Podcast::EXPLICIT_ALIASES[value] || value)
  end

  def explicit_content
    (explicit || podcast&.explicit) == 'true'
  end

  def item_guid
    original_guid || "prx_#{podcast_id}_#{guid}"
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

  def media_url
    media = first_media_resource
    if media
      enclosure_url(
        media.media_url_for_base(base_published_url),
        media.original_url
      )
    end
  end

  def content_type
    first_media_resource.try(:mime_type) || 'audio/mpeg'
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
    original = Hash[original.map { |k, v| ["original_#{k}".to_sym, v] }]
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

  def duration
    if contents.blank?
      enclosure.try(:duration).to_f
    else
      contents.inject(0.0) { |s, c| s + c.duration.to_f }
    end + podcast.try(:duration_padding).to_f
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
    images.each { |i| i.copy_media(force) }
  end

  def podcast_feed_url
    podcast&.url || podcast&.published_url
  end

  def base_published_url
    "https://#{feeder_cdn_host}/#{path}"
  end

  def path
    "#{podcast.try(:path)}/#{guid}"
  end

  def include_in_feed?
    !media? || media_ready?
  end

  def media?
    !all_media_files.blank?
  end

  def media_status
    states = all_media_files.map(&:status).uniq
    if !(%w[started created processing retrying] & states).empty?
      'processing'
    elsif states.any? { |s| s == 'error' }
      'error'
    elsif media_ready?
      'complete'
    end
  end

  def media_ready?
    # if this episode has enclosores, media is ready if there is a complete one
    if !enclosures.blank?
      !!enclosure
      # if this episode has contents, ready when each position is ready
    elsif !all_contents.blank?
      max_pos = all_contents.map(&:position).max
      contents.size == max_pos
      # if this episode has no audio, the media can't be ready, and `media?` will be false
    else
      false
    end
  end

  def first_media_resource
    all_media_files.first
  end

  def enclosure_template
    podcast.try(:enclosure_template)
  end

  def enclosure_prefix
    podcast.try(:enclosure_prefix)
  end

  def podcast_slug
    podcast.path
  end

  # used in the API, both read and write
  def media_files
    !contents.blank? ? contents : Array(enclosure)
  end

  # API updates for media= ... just append new files and reprocess
  def media_files=(files)
    ignore = %i[id type episode_id guid position status created_at updated_at]
    files.each_with_index do |f, index|
      file = f.attributes.with_indifferent_access.except(*ignore)
      file[:position] = index + 1
      all_contents << Content.new(file)
    end

    # find all contents with a greater position and whack them
    all_contents.where(['position > ?', files.count]).destroy_all
  end

  # find existing content by the last 2 segments of the url
  def find_existing_content(pos, url)
    return nil if url.blank?
    content_file = URI.parse(url || '').path.split('/')[-2, 2].join('/')
    content_file = "/#{content_file}" unless content_file[0] == '/'
    all_contents.where(position: pos).where(
      'original_url like ?',
      "%#{content_file}"
    ).order(created_at: :desc).first
  end

  def find_existing_image(url)
    return nil if url.blank?
    images.where(original_url: url).order(created_at: :desc).first
  end

  def all_media_files
    !all_contents.blank? ? all_contents : Array(enclosures)
  end

  def audio_files
    media_files
  end

  def set_external_keyword
    return unless !published_at.nil? && keyword_xid.nil?
    identifiers = []
    %i[published_at guid].each do |attr|
      identifiers << sanitize_keyword(self.send(attr), 10)
    end
    identifiers << sanitize_keyword(title || 'undefined', 20)
    self.keyword_xid = identifiers.join('_')
  end

  def sanitize_keyword(kw, length)
    kw.to_s.downcase.gsub(/[^ a-z0-9_-]/, '').gsub(/\s+/, ' ').strip.slice(
      0,
      length
    )
  end

  def sanitize_text
    self.description = sanitize_white_list(description) if description_changed?
    self.content = sanitize_white_list(content) if content_changed?
    self.subtitle = sanitize_text_only(subtitle) if subtitle_changed?
    self.summary = sanitize_links_only(summary) if summary_changed?
    self.title = sanitize_text_only(title) if title_changed?
    self.keywords = keywords.map { |kw| sanitize_keyword(kw, kw.length) }
  end

  def feeder_cdn_host
    ENV['FEEDER_CDN_HOST']
  end
end
