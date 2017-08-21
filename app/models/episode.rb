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
    class_name: 'EpisodeImage',
    autosave: true,
    dependent: :destroy

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

  before_validation :initialize_guid, :set_external_keyword, :sanitize_text

  after_save :publish_updated, if: -> (e) { e.published_at_changed? }

  scope :published, -> { where('published_at IS NOT NULL AND published_at <= now()') }

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

  def media_url
    media = first_media_resource
    enclosure_url(media.media_url, media.original_url) if media
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
    images.each{ |i| i.copy_media(force) }
  end

  def base_published_url
    "https://#{feeder_cdn_host}/#{path}"
  end

  def path
    "#{podcast.path}/#{guid}"
  end

  def include_in_feed?
    !media? || media_ready?
  end

  def media?
    !all_media_files.blank?
  end

  def media_status
    states = all_media_files.map { |f| f.status }.uniq
    if !(['started', 'created', 'processing', 'retrying'] & states).empty?
      'processing'
    elsif states.any?{ |s| s == 'error' }
      'error'
    elsif media_ready?
      'complete'
    end
  end

  def media_ready?
    # if this episode has enclosores, media is ready if there is a complete one
    if !enclosures.blank?
      enclosure
    # if this episode has contents, ready when each position is ready
    elsif !all_contents.blank?
      max_pos = all_contents.map { |c| c.position }.max
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
    podcast.enclosure_template
  end

  def enclosure_prefix
    podcast.enclosure_prefix
  end

  def podcast_slug
    podcast.path
  end

  # used in the API, both read and write
  def media_files
    if !contents.blank?
      contents
    else
      Array(enclosure)
    end
  end

  def media_files=(files)
    update_contents(files)
  end

  def update_contents(files)
    ignore = [:id, :type, :episode_id, :guid, :position, :status, :created_at, :updated_at]
    files.each_with_index do |f, index|
      file = f.attributes.with_indifferent_access.except(*ignore)
      file[:position] = index + 1
      existing_content = find_existing_content(file[:position], file[:original_url])

      # If there is an existing file with the same url, update
      if existing_content
        existing_content.update_attributes(file)
      # Otherwise, make a new content to be or replace content for that position
      # If there is no file, or the file has a different url
      else
        all_contents << Content.new(file)
      end
    end

    # find all contents with a greater position and whack them
    all_contents.where(['position > ?', files.count]).destroy_all
  end

  def find_existing_content(pos, url)
    return nil if url.blank?
    content_file = URI.parse(url || '').path.split('/')[-2, 2].join('/')
    content_file = "/#{content_file}" unless content_file[0] == '/'
    all_contents.
      where(position: pos).
      where('original_url like ?', "%#{content_file}").
      order(created_at: :desc).
      first
  end

  def find_existing_image(url)
    return nil if url.blank?
    images.
      where(original_url: url).
      order(created_at: :desc).
      first
  end

  def all_media_files
    if !all_contents.blank?
      all_contents
    else
      Array(enclosures)
    end
  end

  def audio_files
    media_files
  end

  def set_external_keyword
    return unless !published_at.nil? && keyword_xid.nil?
    identifiers = []
    [:published_at, :guid].each do |attr|
      identifiers << self.send(attr).to_s.slice(0, 10)
    end
    identifiers << (title || 'undefined').slice(0, 20)
    # Adzerk does not allow commas or colons in keywords; omitting dashes for space
    identifiers.map! { |id| id.downcase.gsub(/[:,-]/,'').gsub(/\s+/,'').strip }
    self.keyword_xid = identifiers.join('_')
  end

  def sanitize_text
    self.description = sanitize_white_list(description) if description_changed?
    self.content = sanitize_white_list(content) if content_changed?
    self.subtitle = sanitize_text_only(subtitle) if subtitle_changed?
    self.summary = sanitize_links_only(summary) if summary_changed?
    self.title = sanitize_text_only(title) if title_changed?
  end

  def feeder_cdn_host
    ENV['FEEDER_CDN_HOST']
  end
end
