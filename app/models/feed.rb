require "hash_serializer"

class Feed < ApplicationRecord
  DEFAULT_FILE_NAME = "feed-rss.xml".freeze

  AUDIO_MIME_TYPES = {
    "mp3" => "audio/mpeg",
    "flac" => "audio/flac",
    "wav" => "audio/wav"
  }.freeze

  include TextSanitizer

  serialize :include_zones, JSON
  serialize :include_tags, JSON
  serialize :exclude_tags, JSON
  serialize :audio_format, HashSerializer

  belongs_to :podcast, -> { with_deleted }, optional: true
  has_many :feed_tokens, autosave: true, dependent: :destroy
  alias_attribute :tokens, :feed_tokens

  has_many :apple_configs, autosave: true, dependent: :destroy, foreign_key: :public_feed_id,
    class_name: "::Apple::Config"

  has_one :feed_image, -> { complete.order("created_at DESC") }, autosave: true, dependent: :destroy
  has_many :feed_images, -> { order("created_at DESC") }, autosave: true, dependent: :destroy
  has_one :itunes_image, -> { complete.order("created_at DESC") }, autosave: true, dependent: :destroy
  has_many :itunes_images, -> { order("created_at DESC") }, autosave: true, dependent: :destroy

  validates :slug, allow_nil: true, uniqueness: {scope: :podcast_id, allow_nil: false}
  validates_format_of :slug, allow_nil: true, with: /\A[0-9a-zA-Z_-]+\z/
  validates_format_of :slug, without: /\A(images|\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\z/
  validates :file_name, presence: true, format: {with: /\A[0-9a-zA-Z_.-]+\z/}
  validates :include_zones, placement_zones: true
  validates :include_tags, tag_list: true
  validates :audio_format, audio_format: true

  after_initialize :set_defaults
  before_validation :sanitize_text

  scope :default, -> { where(slug: nil) }

  def self.enclosure_template_default
    "https://#{ENV["DOVETAIL_HOST"]}{/podcast_id,feed_slug,guid,original_basename}{feed_extension}"
  end

  def set_defaults
    self.file_name ||= DEFAULT_FILE_NAME
    self.enclosure_template ||= Feed.enclosure_template_default
  end

  def sanitize_text
    self.description = sanitize_white_list(description) if description_changed?
    self.subtitle = sanitize_text_only(subtitle) if subtitle_changed?
    self.summary = sanitize_links_only(summary) if summary_changed?
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
    if private?
      "#{podcast.base_private_url}/#{published_path}{?auth}"
    else
      "#{podcast.base_published_url}/#{published_path}"
    end
  end

  def published_path
    default? ? file_name : "#{slug}/#{file_name}"
  end

  def feed_episodes
    include_in_feed = []
    feed_max = display_episodes_count.to_i

    filtered_episodes.each do |ep|
      include_in_feed << ep if ep.include_in_feed?
      break if (feed_max > 0) && (include_in_feed.size >= feed_max)
    end
    include_in_feed
  end

  def episode_categories_include?(ep, match_tags)
    tags = match_tags.map { |cat| normalize_category(cat) }
    cats = (ep || []).categories.map { |cat| normalize_category(cat) }
    (tags & cats).length > 0
  end

  def normalize_category(cat)
    cat.to_s.downcase.gsub(/[^ a-z0-9_-]/, "").gsub(/\s+/, " ").strip
  end

  def publish_to_apple?(apple_config)
    apple_config.present? &&
      apple_config.public_feed == self &&
      apple_config.publish_enabled?
  end

  def use_include_tags?
    !include_tags.blank?
  end

  def use_exclude_tags?
    !exclude_tags.blank?
  end

  def filtered_episodes
    eps = podcast.episodes.published_by(episode_offset_seconds.to_i)

    eps =
      if use_include_tags?
        eps.select { |ep| episode_categories_include?(ep, include_tags) }
      else
        eps
      end

    if use_exclude_tags?
      eps.reject { |ep| episode_categories_include?(ep, exclude_tags) }
    else
      eps
    end
  end

  def enclosure_template
    self[:enclosure_template] || Feed.enclosure_template_default
  end

  def mime_type
    f = (audio_format || {})[:f] || "mp3"
    AUDIO_MIME_TYPES[f]
  end

  def copy_media(force = false)
    feed_images.each { |i| i.copy_media(force) }
    itunes_images.each { |i| i.copy_media(force) }
  end

  # API updates for feed_image=
  def feed_image_file
    feed_images.first
  end

  def feed_image_file=(file)
    img = FeedImage.build(file)
    if img && img.original_url != feed_image_file.try(:original_url)
      feed_images << img
    elsif !img
      feed_images.destroy_all
    end
  end

  # API updates for itunes_image=
  def itunes_image_file
    itunes_images.first
  end

  def itunes_image_file=(file)
    img = ITunesImage.build(file)
    if img && img.original_url != itunes_image_file.try(:original_url)
      itunes_images << img
    elsif !img
      itunes_images.destroy_all
    end
  end
end
