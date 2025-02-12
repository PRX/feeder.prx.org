require "addressable/uri"
require "addressable/template"
require "hash_serializer"
require "text_sanitizer"

class Episode < ApplicationRecord
  include EpisodeAdBreaks
  include EpisodeFilters
  include EpisodeHasFeeds
  include EpisodeMedia
  include PublishingStatus
  include TextSanitizer
  include EmbedPlayerHelper
  include AppleDelivery
  include ReleaseEpisodes

  MAX_SEGMENT_COUNT = 10
  MAX_DESCRIPTION_BYTES = 4000
  VALID_ITUNES_TYPES = %w[full trailer bonus]
  DROP_DATE = "COALESCE(episodes.published_at, episodes.released_at)"

  attr_accessor :strict_validations

  acts_as_paranoid

  belongs_to :podcast, -> { with_deleted }, touch: true

  # See concerns/episode_media.rb for media/audio related code, e.g. the associations
  has_many :media_versions, -> { order("created_at DESC") }, dependent: :destroy
  has_many :contents, -> { order("position ASC, created_at DESC") }, autosave: true, dependent: :destroy, inverse_of: :episode
  has_one :uncut, -> { order("created_at DESC") }, autosave: true, dependent: :destroy, inverse_of: :episode
  has_one :external_media_resource, -> { order("created_at DESC") }, autosave: true, dependent: :destroy, inverse_of: :episode

  has_many :episode_imports
  has_many :images, -> { order("created_at DESC") }, class_name: "EpisodeImage", autosave: true, dependent: :destroy, inverse_of: :episode

  has_one :ready_image, -> { complete_or_replaced.order("created_at DESC") }, class_name: "EpisodeImage"
  has_one :transcript, -> { order("created_at DESC") }, dependent: :destroy, inverse_of: :episode

  accepts_nested_attributes_for :contents, allow_destroy: true, reject_if: ->(c) { c[:id].blank? && c[:original_url].blank? }
  accepts_nested_attributes_for :uncut, allow_destroy: true, reject_if: ->(u) { u[:id].blank? && u[:original_url].blank? }
  accepts_nested_attributes_for :images, allow_destroy: true, reject_if: ->(i) { i[:id].blank? && i[:original_url].blank? }
  accepts_nested_attributes_for :transcript, allow_destroy: true, reject_if: ->(t) { t[:id].blank? && t[:original_url].blank? }

  validates :podcast_id, :guid, presence: true
  validates :title, presence: true
  validates :description, bytesize: {maximum: MAX_DESCRIPTION_BYTES}, if: -> { strict_validations && description_changed? }
  validates :url, http_url: true
  validates :original_guid, presence: true, uniqueness: {scope: :podcast_id}, allow_nil: true
  alias_error_messages :item_guid, :original_guid
  validates :itunes_type, inclusion: {in: VALID_ITUNES_TYPES}
  validates :episode_number, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
  validates :season_number, numericality: {only_integer: true, greater_than: 0}, allow_nil: true
  validates :explicit, inclusion: {in: %w[true false]}, allow_nil: true
  validates :segment_count, presence: true, if: :strict_validations
  validates :segment_count, numericality: {only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_SEGMENT_COUNT}, allow_nil: true

  before_validation :set_defaults, :set_external_keyword, :sanitize_text

  after_save :publish_updated, if: ->(e) { e.published_at_previously_changed? }

  scope :published, -> { where("episodes.published_at IS NOT NULL AND episodes.published_at <= now()") }
  scope :published_by, ->(offset) { where("episodes.published_at IS NOT NULL AND episodes.published_at <= ?", Time.now - offset) }
  scope :draft, -> { where("episodes.published_at IS NULL") }
  scope :scheduled, -> { where("episodes.published_at IS NOT NULL AND episodes.published_at > now()") }
  scope :draft_or_scheduled, -> { draft.or(scheduled) }
  scope :after, ->(time) { where("#{DROP_DATE} >= ?", time) }
  scope :before, ->(time) { where("#{DROP_DATE} < ?", time) }
  scope :filter_by_title, ->(text) { where("episodes.title ILIKE ?", "%#{text}%") if text.present? }
  scope :dropdate_asc, -> { reorder(Arel.sql("#{DROP_DATE} ASC NULLS FIRST")) }
  scope :dropdate_desc, -> { reorder(Arel.sql("#{DROP_DATE} DESC NULLS LAST")) }

  alias_attribute :number, :episode_number
  alias_attribute :season, :season_number

  def self.by_prx_story(story)
    Episode.find_by(prx_uri: story_uri(story))
  end

  def self.story_uri(story)
    (story.links["self"].href || "").gsub("/authorization/", "/")
  end

  # use guid rather than id for episode routes
  def to_param
    guid
  end

  def generate_item_guid
    self.class.generate_item_guid(podcast_id, guid)
  end

  def self.generate_item_guid(podcast_id, episode_guid)
    "prx_#{podcast_id}_#{episode_guid}"
  end

  def self.decode_item_guid(item_guid)
    item_guid.sub(/^prx_[0-9]+_/, "") if item_guid&.starts_with?("prx_")
  end

  def self.find_by_item_guid(guid)
    where(original_guid: guid).or(where(original_guid: nil, guid: decode_item_guid(guid))).first
  end

  def publish_updated
    podcast&.publish_updated
  end

  def published?
    !published_at.nil? && published_at <= Time.now
  end

  def published_by?(offset)
    !published_at.nil? && published_at <= Time.now - offset
  end

  def draft?
    published_at.nil?
  end

  def was_draft?
    published_at_changed? ? published_at_was.nil? : draft?
  end

  def author=(a)
    author = a || {}
    self.author_name = author["name"]
    self.author_email = author["email"]
  end

  def image
    images.first
  end

  def image=(file)
    img = EpisodeImage.build(file)

    if !img
      images.each(&:mark_for_destruction)
    elsif img&.replace?(image)
      images.build(img.attributes.compact)
    else
      img.update_image(image)
    end
  end

  def set_defaults
    guid
    self.segment_count ||= 1 if new_record? && strict_validations
  end

  def guid
    self[:guid] ||= SecureRandom.uuid
    self[:guid]
  end

  def explicit=(value)
    super Podcast::EXPLICIT_ALIASES.fetch(value, value)
  end

  def explicit_content
    (explicit || podcast&.explicit) == "true"
  end

  # UI displays nil as "inherit"
  def explicit_option
    explicit.nil? ? "inherit" : explicit
  end

  def explicit_option=(value)
    self.explicit = ((value == "inherit") ? nil : value)
  end

  def explicit_option_was
    explicit_was.nil? ? "inherit" : explicit_was
  end

  def item_guid
    original_guid || generate_item_guid
  end

  def item_guid=(new_guid)
    self.original_guid = (new_guid.blank? || new_guid == generate_item_guid) ? nil : new_guid
  end

  def url
    super || embed_player_landing_url(podcast, self)
  end

  def url=(new_url)
    super(embed_url?(new_url) ? nil : new_url)
  end

  def url_was
    super || embed_player_landing_url(podcast, self)
  end

  def categories
    self[:categories] || []
  end

  def categories=(cats)
    self[:categories] = sanitize_categories(cats, false).presence
  end

  def publish!
    Rails.logger.tagged("Episode#publish!") do
      apple_mark_for_reupload!
      podcast&.publish!
    end
  end

  def podcast_feed_url
    podcast&.public_url
  end

  def base_published_url
    "https://#{feeder_cdn_host}/#{path}"
  end

  def path
    "#{podcast.try(:path)}/#{guid}"
  end

  def enclosure_url(feed = nil)
    EnclosureUrlBuilder.new.podcast_episode_url(podcast, self, feed)
  end

  def enclosure_filename(feed = nil)
    uri = URI.parse(enclosure_url(feed))
    File.basename(uri.path)
  end

  def set_external_keyword
    return unless !published_at.nil? && keyword_xid.nil?

    identifiers = []
    %i[published_at guid].each do |attr|
      identifiers << sanitize_category(send(attr), 10, true)
    end
    identifiers << sanitize_category(title || "undefined", 20, true)
    self.keyword_xid = identifiers.join("_")
  end

  def sanitize_text
    self.description = sanitize_white_list(description) if description_changed?
    self.subtitle = sanitize_text_only(subtitle) if subtitle_changed?
    self.title = sanitize_text_only(title) if title_changed?
    self.original_guid = original_guid.strip if !original_guid.blank? && original_guid_changed?
  end

  # This value is safe to use in the RSS and integrations
  def description_with_default
    [description, subtitle, title].detect { |d| d.present? } || ""
  end

  def description_safe
    description_with_default.truncate_bytes(MAX_DESCRIPTION_BYTES, omission: "")
  end

  def feeder_cdn_host
    ENV["FEEDER_CDN_HOST"]
  end

  def published_or_released_date
    if published_at.present?
      published_at
    elsif released_at.present?
      released_at
    end
  end

  def ready_transcript
    transcript if transcript&.status_complete?
  end
end
