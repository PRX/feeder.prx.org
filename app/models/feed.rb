require 'hash_serializer'

class Feed < BaseModel
  DEFAULT_FILE_NAME = 'feed-rss.xml'.freeze

  AUDIO_MIME_TYPES = {
    'mp3' => 'audio/mpeg',
    'flac' => 'audio/flac',
    'wav' => 'audio/wav'
  }.freeze

  include TextSanitizer

  serialize :include_zones, JSON
  serialize :include_tags, JSON
  serialize :audio_format, HashSerializer

  belongs_to :podcast, -> { with_deleted }
  has_many :feed_tokens, autosave: true, dependent: :destroy
  alias_attribute :tokens, :feed_tokens

  validates :slug, allow_nil: true, uniqueness: { scope: :podcast_id, allow_nil: false }
  validates_format_of :slug, allow_nil: true, with: /\A[0-9a-zA-Z_-]+\z/
  validates_format_of :slug, without: /\A(images|\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\z/
  validates :file_name, presence: true, format: { with: /\A[0-9a-zA-Z_.-]+\z/ }
  validates :include_zones, placement_zones: true
  validates :include_tags, tag_list: true
  validates :audio_format, audio_format: true

  after_initialize :set_defaults
  before_validation :sanitize_text

  scope :default, -> { where(slug: nil) }

  def self.enclosure_template_default
    "https://#{ENV['DOVETAIL_HOST']}{/podcast_id,feed_slug,guid,original_basename}{feed_extension}"
  end

  def set_defaults
    self.file_name ||= DEFAULT_FILE_NAME
    self.enclosure_template ||= Feed.enclosure_template_default
  end

  def sanitize_text
    self.title = sanitize_text_only(title) if title_changed?
  end

  def default?
    slug.nil?
  end

  def public?
    !private?
  end

  def default_runtime_settings?
    default? && public? && include_zones.nil? && audio_format.blank?
  end

  def published_url
    "#{podcast.base_published_url}/#{published_path}"
  end

  def published_path
    default? ? file_name : "#{slug}/#{file_name}"
  end

  def feed_episodes
    include_in_feed = []
    feed_max = display_episodes_count.to_i
    filtered_episodes.each do |ep|
      next unless include_episode_categories?(ep)
  
      include_in_feed << ep if ep.include_in_feed?
      break if (feed_max > 0) && (include_in_feed.size >= feed_max)
    end
    include_in_feed
  end

  def include_episode_categories?(ep)
    return true if (include_tags || []).length <= 0
    tags = include_tags.map { |cat| normalize_category(cat) }
    cats = (ep || []).categories.map { |cat| normalize_category(cat) }
    (tags & cats).length > 0
  end

  def normalize_category(cat)
    cat.to_s.downcase.gsub(/[^ a-z0-9_-]/, '').gsub(/\s+/, ' ').strip
  end

  def filtered_episodes
    podcast.episodes.published_by(episode_offset_seconds.to_i)
  end

  def enclosure_template
    self[:enclosure_template] || Feed.enclosure_template_default
  end

  def mime_type
    f = (audio_format || {})[:f] || 'mp3'
    AUDIO_MIME_TYPES[f]
  end
end
