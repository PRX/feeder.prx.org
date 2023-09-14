require "hash_serializer"

class Feed < ApplicationRecord
  include FeedAudioFormat
  include FeedAdZone

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

  belongs_to :podcast, -> { with_deleted }, optional: true, touch: true
  has_many :feed_tokens, autosave: true, dependent: :destroy
  alias_attribute :tokens, :feed_tokens
  accepts_nested_attributes_for :feed_tokens, allow_destroy: true, reject_if: ->(ft) { ft[:token].blank? }

  has_many :apple_configs, autosave: true, dependent: :destroy, foreign_key: :public_feed_id,
    class_name: "::Apple::Config"

  has_many :feed_images, -> { order("created_at DESC") }, autosave: true, dependent: :destroy
  has_many :itunes_images, -> { order("created_at DESC") }, autosave: true, dependent: :destroy
  has_many :itunes_categories, validate: true, autosave: true, dependent: :destroy

  has_one :apple_sync_log, -> { feeds }, foreign_key: :feeder_id, class_name: "SyncLog"

  accepts_nested_attributes_for :feed_images, allow_destroy: true, reject_if: ->(i) { i[:id].blank? && i[:original_url].blank? }
  accepts_nested_attributes_for :itunes_images, allow_destroy: true, reject_if: ->(i) { i[:id].blank? && i[:original_url].blank? }

  acts_as_paranoid

  validates :slug, allow_nil: true, uniqueness: {scope: :podcast_id, allow_nil: false}
  validates_format_of :slug, allow_nil: true, with: /\A[0-9a-zA-Z_-]+\z/
  validates_format_of :slug, without: /\A(images|\w{8}-\w{4}-\w{4}-\w{4}-\w{12})\z/
  validates :file_name, presence: true, format: {with: /\A[0-9a-zA-Z_.-]+\z/}
  validates :include_zones, placement_zones: true
  validates :include_tags, tag_list: true
  validates :audio_format, audio_format: true
  validates :title, presence: true, unless: :default?
  validates :url, http_url: true
  validates :new_feed_url, http_url: true
  validates :enclosure_prefix, http_url: true
  validates :display_episodes_count, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
  validates :display_full_episodes_count, numericality: {only_integer: true, greater_than: 0}, allow_nil: true

  after_initialize :set_defaults
  before_validation :sanitize_text
  before_create :set_public_feeds_url
  before_save :remove_url, if: :private?

  scope :default, -> { where(slug: nil) }
  scope :custom, -> { where.not(slug: nil) }
  scope :tab_order, -> { order(Arel.sql("slug IS NULL DESC, created_at ASC")) }

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

  def set_public_feeds_url
    if public? && url.blank? && ENV["PUBLIC_FEEDS_URL_PREFIX"].present?
      self.url = "#{ENV["PUBLIC_FEEDS_URL_PREFIX"]}/#{podcast.path}/#{published_path}"
    end
  end

  def remove_url
    self.url = nil
  end

  def default?
    slug.nil?
  end

  def custom?
    !default?
  end

  def public?
    !private?
  end

  def default_runtime_settings?
    default? && public? && include_zones.nil? && audio_format.blank?
  end

  def published_url(include_token = nil)
    if private?
      published_private_url(include_token)
    else
      published_public_url
    end
  end

  def published_public_url
    "#{podcast&.base_published_url}/#{published_path}"
  end

  def published_private_url(include_token = nil)
    private_path = "#{podcast.base_private_url}/#{published_path}"

    if include_token == true
      "#{private_path}?auth=#{tokens.first&.token}"
    elsif include_token.present?
      "#{private_path}?auth=#{include_token}"
    elsif include_token.nil?
      "#{private_path}{?auth}"
    else
      private_path
    end
  end

  def public_url(include_token = nil)
    url.present? ? url : published_url(include_token)
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

  def include_tags=(tags)
    tags = Array(tags).reject(&:blank?)
    self[:include_tags] = tags.blank? ? nil : tags
  end

  def exclude_tags=(tags)
    tags = Array(tags).reject(&:blank?)
    self[:exclude_tags] = tags.blank? ? nil : tags
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

  def ready_feed_image
    feed_images.complete_or_replaced.first
  end

  def feed_image
    feed_images.first
  end

  def feed_image=(file)
    img = FeedImage.build(file)

    if !img
      feed_images.each(&:mark_for_destruction)
    elsif img&.replace?(feed_image)
      feed_images.build(img.attributes.compact)
    else
      img.update_image(feed_image)
    end
  end

  def ready_itunes_image
    itunes_images.complete_or_replaced.first
  end

  def itunes_image
    itunes_images.first
  end

  def itunes_image=(file)
    img = ITunesImage.build(file)

    if !img
      itunes_images.each(&:mark_for_destruction)
    elsif img&.replace?(itunes_image)
      itunes_images.build(img.attributes.compact)
    else
      img.update_image(itunes_image)
    end
  end

  def ready_image
    @ready_image ||= (ready_feed_image || ready_itunes_image)
  end

  def itunes_category
    itunes_categories[0]&.name
  end

  def itunes_category=(value)
    cat = itunes_categories[0] || itunes_categories.build

    # allow destroying for non-default feeds
    if custom? && value.blank?
      cat.mark_for_destruction
    elsif cat.name != value
      cat.name = value
      cat.subcategories = []
    end
  end

  def itunes_subcategory
    itunes_categories[0]&.subcategories&.first
  end

  def itunes_subcategory=(value)
    if (cat = itunes_categories[0])
      cat.subcategories = [value]
    else
      itunes_categories.build(subcategories: [value])
    end
  end
end
