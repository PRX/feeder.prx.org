require "text_sanitizer"

class Podcast < ApplicationRecord
  FEED_ATTRS = %i[subtitle description summary url new_feed_url display_episodes_count
    display_full_episodes_count enclosure_prefix enclosure_template feed_image itunes_image
    ready_feed_image ready_itunes_image ready_image itunes_category itunes_subcategory itunes_categories]
  FEED_GETTERS = FEED_ATTRS.map { |s| [s, "#{s}_was".to_sym, "#{s}_changed?".to_sym] }.flatten
  FEED_SETTERS = FEED_ATTRS.map { |s| "#{s}=".to_sym }

  include TextSanitizer
  include AdvisoryLocks
  include EmbedPlayerHelper
  include PodcastFilters
  include ReleaseEpisodes

  acts_as_paranoid

  serialize :restrictions, coder: JSON

  has_one :default_feed, -> { default }, class_name: "Feed", validate: true, autosave: true, inverse_of: :podcast
  alias_method :public_feed, :default_feed

  has_many :episodes, -> { order("published_at desc") }, dependent: :destroy
  has_many :feeds, dependent: :destroy
  has_many :tasks, as: :owner
  has_many :podcast_imports, dependent: :destroy

  accepts_nested_attributes_for :default_feed

  validates :title, presence: true
  validates :link, http_url: true
  validates :donation_url, http_url: true
  validates :payment_pointer, format: /\A\$[A-Za-z0-9\-.]+\/?[^\s]*\z/, allow_blank: true
  validates :path, :prx_uri, :source_url, uniqueness: true, allow_nil: true
  validates :restrictions, media_restrictions: true

  # these keep changing - so just translate to the current accepted values
  VALID_EXPLICITS = %w[false true]
  EXPLICIT_ALIASES = {
    "" => nil,
    "no" => "false",
    "clean" => "false",
    false => "false",
    "yes" => "true",
    "explicit" => "true",
    true => "true"
  }.freeze
  validates :explicit, inclusion: {in: VALID_EXPLICITS}, allow_nil: false

  before_validation :set_defaults, :sanitize_text

  scope :filter_by_title, ->(text) { where("podcasts.title ILIKE ?", "%#{text}%") if text.present? }
  scope :published, -> { where("published_at IS NOT NULL AND published_at <= now()") }

  def self.by_prx_series(series)
    series_uri = series.links["self"].href
    Podcast.find_by(prx_uri: series_uri)
  end

  def set_defaults
    self.explicit ||= "false"
  end

  def default_feed
    super || build_default_feed(podcast: self, private: false)
  end

  def apple_config
    if defined?(@apple_config)
      @apple_config
    else
      @apple_config = Apple::Config.where(feed_id: feeds.pluck(:id)).first
    end
  end

  def reload(options = nil)
    remove_instance_variable(:@apple_config) if defined?(@apple_config)
    super
  end

  def explicit=(value)
    super Podcast::EXPLICIT_ALIASES.fetch(value, value)
  end

  def publish_updated
    update_column(:published_at, max_episode_published_at || Time.now)
  end

  def published?
    !published_at.nil? && published_at <= Time.now
  end

  def pub_date
    published_at
  end

  def max_episode_published_at
    episodes.published.maximum(:published_at)
  end

  def last_build_date
    updated_at
  end

  def account_id(uri = prx_account_uri)
    URI.parse(uri || "").path.split("/").last.to_i
  end

  def account_id_was
    if prx_account_uri_changed? && prx_account_uri_was.present?
      account_id(prx_account_uri_was)
    else
      account_id
    end
  end

  def path
    self[:path] || id
  end

  def link
    super || embed_player_landing_url(self)
  end

  def link=(new_link)
    super(embed_url?(new_link) ? nil : new_link)
  end

  def link_was
    super || embed_player_landing_url(self)
  end

  def owners=(os)
    owner = Array(os).first || {}
    self.owner_name = owner["name"]
    self.owner_email = owner["email"]
  end

  def author=(a)
    author = a || {}
    self.author_name = author["name"]
    self.author_email = author["email"]
  end

  def managing_editor=(me)
    managing_editor = me || {}
    self.managing_editor_name = managing_editor["name"]
    self.managing_editor_email = managing_editor["email"]
  end

  def managing_editor
    return nil unless managing_editor_name || managing_editor_email
    "#{managing_editor_email} (#{managing_editor_name})"
  end

  def categories
    self[:categories] || []
  end

  def categories=(cats)
    self[:categories] = sanitize_categories(cats, false).presence
  end

  def publish!
    if locked?
      Rails.logger.warn "Podcast #{id} is locked, skipping publish", {podcast_id: id}
      return false
    end

    StartPublishingPipelineJob.perform_later(self)
  end

  def with_publish_lock(&block)
    with_advisory_lock(PODCAST_PUBLISHING_ADVISORY_LOCK_TYPE, &block)
  end

  def copy_media(force = false)
    feeds.each { |f| f.copy_media(force) }
  end

  def web_master
    ENV["FEEDER_WEB_MASTER"]
  end

  def generator
    ENV["FEEDER_GENERATOR"]
  end

  def base_published_url
    "https://#{feeder_cdn_host}/#{path}"
  end

  def base_private_url
    "https://#{feeder_cdn_private_host}/#{path}"
  end

  def published_url(include_token = nil)
    default_feed&.published_url(include_token)
  end

  def public_url(include_token = nil)
    default_feed&.public_url(include_token)
  end

  def itunes_type
    serial_order ? "serial" : "episodic"
  end

  def sanitize_text
    self.title = sanitize_text_only(title) if title_changed?
  end

  def feeder_cdn_host
    ENV["FEEDER_CDN_HOST"]
  end

  def feeder_cdn_private_host
    ENV["FEEDER_CDN_PRIVATE_HOST"]
  end

  def default_feed_settings?
    feeds.all?(&:default_runtime_settings?)
  end

  # TODO: temporary delegations, until Publish + our Representers get updated
  # the tests also seem to have issues with this - and the need for just-in-time
  # initializing the default feed
  def method_missing(method, *args, &block)
    if FEED_GETTERS.include?(method)
      default_feed.try(:public_send, method, *args, &block)
    elsif FEED_SETTERS.include?(method)
      self.default_feed ||= feeds.new(private: false)
      default_feed.public_send(method, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method, *args)
    if FEED_GETTERS.include?(method) || FEED_SETTERS.include?(method)
      true
    else
      super
    end
  end
end
