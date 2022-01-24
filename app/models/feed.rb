require 'hash_serializer'

class Feed < BaseModel
  DEFAULT_FILE_NAME = 'feed-rss.xml'.freeze

  include TextSanitizer

  serialize :filter_zones, JSON
  serialize :filter_tags, JSON
  serialize :audio_format, HashSerializer

  belongs_to :podcast, -> { with_deleted }
  has_many :feed_tokens, dependent: :destroy
  alias_attribute :tokens, :feed_tokens

  validates :slug, allow_nil: true, uniqueness: { scope: :podcast_id, allow_nil: false }
  validates_format_of :slug, allow_nil: true, with: /\A[0-9a-zA-Z_-]+\z/
  validates_format_of :slug, without: /\A(images|\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\z/
  validates :file_name, presence: true, format: { with: /\A[0-9a-zA-Z_.-]+\z/ }
  validates :filter_zones, placement_zones: true
  validates :filter_tags, tag_list: true
  validates :audio_format, audio_format: true

  after_initialize :set_defaults
  before_validation :sanitize_text

  scope :default, -> { where(slug: nil) }

  def set_defaults
    self.file_name ||= DEFAULT_FILE_NAME
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
    default? && public? && filter_zones.blank? && audio_format.blank?
  end

  def published_url
    if default?
      "#{podcast.base_published_url}/#{file_name}"
    else
      "#{podcast.base_published_url}/#{slug}/#{file_name}"
    end
  end
end
