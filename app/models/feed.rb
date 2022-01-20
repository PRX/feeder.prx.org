class Feed < BaseModel
  DEFAULT_FILE_NAME = 'feed-rss.xml'.freeze

  include TextSanitizer

  serialize :reject_zones, JSON
  serialize :filter_tags, JSON
  serialize :audio_format, HashSerializer

  belongs_to :podcast, -> { with_deleted }
  has_many :feed_tokens, dependent: :destroy

  validates :slug, allow_nil: true, uniqueness: { scope: :podcast_id, allow_nil: false }
  validates_format_of :slug, allow_nil: true, with: /\A[0-9a-zA-Z_-]+\z/
  validates :file_name, presence: true, uniqueness: { scope: :podcast_id }
  validates_format_of :file_name, with: /\A[0-9a-zA-Z_.-]+\z/
  validates_format_of :file_name, without: /\A(images|\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\z/
  validates :reject_zones, placement_zones: true
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
end
