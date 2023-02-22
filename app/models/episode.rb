require "addressable/uri"
require "addressable/template"
require "hash_serializer"
require "text_sanitizer"

class Episode < ApplicationRecord
  include PublishingStatus
  include TextSanitizer

  serialize :categories, JSON
  serialize :keywords, JSON

  acts_as_paranoid

  serialize :overrides, HashSerializer

  belongs_to :podcast, -> { with_deleted }, touch: true

  has_many :images,
    -> { order("created_at DESC") },
    class_name: "EpisodeImage", autosave: true, dependent: :destroy

  has_many :contents,
    -> { order("position ASC, created_at DESC") },
    autosave: true, dependent: :destroy

  has_many :enclosures,
    -> { order("created_at DESC") },
    autosave: true, dependent: :destroy

  has_one :apple_podcast_container, class_name: "Apple::PodcastContainer"
  has_many :apple_podcast_deliveries, through: :apple_podcast_container, source: :podcast_deliveries,
    class_name: "Apple::PodcastDelivery"
  has_many :apple_podcast_delivery_files, through: :apple_podcast_deliveries, source: :podcast_delivery_files,
    class_name: "Apple::PodcastDeliveryFile"

  validates :podcast_id, :guid, presence: true
  validates :title, presence: true
  validates :original_guid, uniqueness: {scope: :podcast_id, allow_nil: true}
  VALID_ITUNES_TYPES = %w[full trailer bonus]
  validates :itunes_type, inclusion: {in: VALID_ITUNES_TYPES}
  validates :episode_number,
    numericality: {only_integer: true}, allow_nil: true
  validates :season_number,
    numericality: {only_integer: true}, allow_nil: true
  validates :explicit, inclusion: {in: %w[true false]}, allow_nil: true

  before_validation :initialize_guid, :set_external_keyword, :sanitize_text

  after_save :publish_updated, if: ->(e) { e.published_at_previously_changed? }

  scope :published, -> { where("published_at IS NOT NULL AND published_at <= now()") }

  scope :published_by, ->(offset) { where("published_at IS NOT NULL AND published_at <= ?", Time.now + offset) }

  alias_attribute :number, :episode_number
  alias_attribute :season, :season_number
  alias_method :podcast_container, :apple_podcast_container

  def self.release_episodes!(_options = {})
    podcasts = []
    episodes_to_release.each do |e|
      podcasts << e.podcast
      e.touch
    end
    podcasts.uniq.each { |p| p.publish_updated && p.publish! }
  end

  def self.episodes_to_release
    where("published_at > updated_at AND published_at <= now()").all
  end

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

  def apple_file_errors?
    # TODO: for now these are all considered audio files

    apple_delivery_file_errors.present?
  end

  def apple_delivery_file_errors
    # TODO: for now these are all considered audio files

    apple_delivery_files.map { |p| p.asset_processing_state["errors"] }.flatten
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

  def ready_image
    images.complete_or_replaced.first
  end

  def image
    images.first
  end

  def image=(file)
    img = EpisodeImage.build(file)

    if !img
      images.each(&:mark_for_destruction)
    elsif img&.replace?(image)
      images.build(img.attributes)
    else
      img.update_image(image)
    end
  end

  def ready_enclosure
    enclosures.complete_or_replaced.first
  end

  def enclosure
    enclosures.first
  end

  def enclosure=(file)
    enc = Enclosure.build(file)

    if !enc
      enclosures.each(&:mark_for_destruction)
    elsif enc&.replace?(enclosure)
      enclosures.build(enc.attributes)
    else
      enc.update_resource(enclosure)
    end
  end

  def ready_contents
    contents.complete_or_replaced.group_by(&:position).values.map(&:first)
  end

  def contents=(files)
    existing = contents.group_by(&:position)

    files&.each_with_index do |file, idx|
      position = idx + 1
      con = Content.build(file, position)

      if !con
        existing[position]&.each(&:mark_for_destruction)
      elsif con.replace?(existing[position]&.first)
        contents.build(con.attributes)
      else
        con.update_resource(existing[position].first)
      end
    end

    # destroy unused positions
    positions = 1..(files&.count.to_i)
    existing.each do |position, contents|
      contents.each(&:mark_for_destruction) unless positions.include?(position)
    end

    contents
  end

  def initialize_guid
    guid
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

  def item_guid
    original_guid || self.class.generate_item_guid(podcast_id, guid)
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

  def categories=(cats)
    self[:categories] = Array(cats).reject(&:blank?)
  end

  def keywords
    self[:keywords] ||= []
  end

  def media_url
    first_media_resource.try(:href)
  end

  def content_type(feed = nil)
    media_content_type = first_media_resource.try(:mime_type)
    if (media_content_type || "").starts_with?("video")
      media_content_type
    else
      feed.try(:mime_type) || media_content_type || "audio/mpeg"
    end
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
    contents.each { |c| c.copy_media(force) }
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
    (segment_count.nil? && !media?) || media_ready?
  end

  def media_resources
    contents.blank? ? Array(enclosure) : contents
  end

  def ready_media_resources
    contents.blank? ? Array(ready_enclosure) : ready_contents
  end

  def media?
    media_resources.any?
  end

  def first_media_resource
    media_resources.first
  end

  def media_status
    states = media_resources.map(&:status).uniq
    if !(%w[started created processing retrying] & states).empty?
      "processing"
    elsif states.any? { |s| s == "error" }
      "error"
    elsif media_ready?
      "complete"
    end
  end

  def media_ready?
    if contents.blank?
      ready_enclosure.present?
    elsif segment_count.nil?
      ready_contents.count == contents.maximum(:position)
    elsif segment_count.positive?
      ready_contents.count == segment_count
    else
      false
    end
  end

  def enclosure_url(feed = nil)
    EnclosureUrlBuilder.new.podcast_episode_url(podcast, self, feed)
  end

  def enclosure_filename
    uri = URI.parse(enclosure_url)
    File.basename(uri.path)
  end

  def set_external_keyword
    return unless !published_at.nil? && keyword_xid.nil?

    identifiers = []
    %i[published_at guid].each do |attr|
      identifiers << sanitize_keyword(send(attr), 10)
    end
    identifiers << sanitize_keyword(title || "undefined", 20)
    self.keyword_xid = identifiers.join("_")
  end

  def sanitize_keyword(kw, length)
    kw.to_s.downcase.gsub(/[^ a-z0-9_-]/, "").gsub(/\s+/, " ").strip.slice(
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
    ENV["FEEDER_CDN_HOST"]
  end
end
