require "text_sanitizer"
require "json"

class Podcast < ApplicationRecord
  FEED_ATTRS = %i[subtitle description url new_feed_url display_episodes_count
    display_full_episodes_count enclosure_prefix enclosure_template feed_image itunes_image
    ready_feed_image ready_itunes_image ready_image itunes_category itunes_subcategory itunes_categories]
  FEED_GETTERS = FEED_ATTRS.map { |s| [s, :"#{s}_was", :"#{s}_changed?"] }.flatten
  FEED_SETTERS = FEED_ATTRS.map { |s| :"#{s}=" }

  # https://github.com/Podcastindex-org/podcast-namespace/blob/main/docs/1.0.md#guid
  PODCAST_NAMESPACE = "ead4c236-bf58-58c6-a2c6-a6b28d128cb6".freeze

  include TextSanitizer
  include AdvisoryLocks
  include EmbedPlayerHelper
  include PodcastFilters
  include ReleaseEpisodes
  include Integrations::PodcastIntegrations
  include PodcastSubscribeLinks
  include MetricsQueries

  acts_as_paranoid

  serialize :restrictions, coder: JSON

  has_one :default_feed, -> { default }, class_name: "Feed", validate: true, autosave: true, inverse_of: :podcast
  alias_method :public_feed, :default_feed
  has_one :stream_recording, validate: true, autosave: true

  has_many :episodes, -> { order("published_at desc") }, dependent: :destroy
  has_many :feeds, dependent: :destroy
  has_many :tasks, as: :owner
  has_many :podcast_imports, dependent: :destroy
  has_many :subscribe_links, dependent: :destroy

  accepts_nested_attributes_for :default_feed
  accepts_nested_attributes_for :subscribe_links, allow_destroy: true

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
  after_commit :set_guid!, if: -> { guid.blank? }

  scope :filter_by_title, ->(text) { where("podcasts.title ILIKE ?", "%#{text}%") if text.present? }
  scope :published, -> { where("published_at IS NOT NULL AND published_at <= now()") }

  def self.by_prx_series(series)
    series_uri = series.links["self"].href
    Podcast.find_by(prx_uri: series_uri)
  end

  def set_guid!
    return unless public_url.present? && id.present? && guid.blank?
    new_guid = Digest::UUID.uuid_v5(PODCAST_NAMESPACE, public_url)
    update_column(:guid, new_guid)
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

  def has_apple_feed?
    feeds.apple.exists?
  end

  def reload(options = nil)
    remove_instance_variable(:@apple_config) if defined?(@apple_config)
    super
  end

  def explicit=(value)
    super(Podcast::EXPLICIT_ALIASES.fetch(value, value))
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

  # publish locking getters/setters, for backwards compatibility in podcast API
  def locked=(val)
    self[:locked_until] = val.present? ? "3000-01-01" : nil
  end

  def locked
    locked_until.present? && locked_until > Time.now
  end

  def locked?
    locked
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

  def itunes_type=(itype)
    self.serial_order = !!itype&.match(/serial/i)
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

  def downloads_by_season(season_number, latest = false)
    season_episodes_guids = episodes.published.where(season_number: season_number).pluck(:guid)
    expiration = latest ? 1.hour : 1.month

    Rails.cache.fetch("#{cache_key_with_version}/downloads_by_season/#{season_number}", expires_in: expiration) do
      Rollups::HourlyDownload
        .where(episode_id: season_episodes_guids)
        .select("SUM(count) AS count")
        .final
        .sum(:count)
    end
  end

  def alltime_downloads
    alltime_downloads_query(id, "podcast_id")
  end

  def daterange_downloads(date_start = default_time_start, date_end = default_time_end, interval = "DAY")
    daterange_downloads_query(id, "podcast_id", date_start, date_end, interval)
  end

  def recent_episodes_downloads(date_start = default_time_start, date_end = default_time_end, interval = "DAY")
    recent_ep_guids = episodes.published.dropdate_desc.limit(10).pluck(:guid)

    daterange_downloads_query(recent_ep_guids, "episode_id", date_start, date_end, interval)
  end

  def feed_downloads
    Rails.cache.fetch("#{cache_key_with_version}/feed_downloads", expires_in: 1.hour) do
      feed_downloads_query(id, "podcast_id", feeds)
    end
  end

  def feed_download_rollups
    sorted_feed_download_rollups(feeds, feed_downloads)
  end

  def top_countries_downloads
    Rails.cache.fetch("#{cache_key_with_version}/top_countries_downloads", expires_in: 1.day) do
      top_countries_downloads_query(id, "podcast_id")
    end
  end

  def other_countries_downloads
    Rails.cache.fetch("#{cache_key_with_version}/other_countries_downloads", expires_in: 1.day) do
      other_countries_downloads_query(id, "podcast_id", top_countries_downloads)
    end
  end

  def country_download_rollups
    all_countries = top_countries_downloads.merge({other: other_countries_downloads})
    all_countries.to_a.map do |country|
      {
        label: Rollups::DailyGeo.label_for(country[0]),
        downloads: country[1]
      }
    end
  end

  def top_agents_downloads
    Rails.cache.fetch("#{cache_key_with_version}/top_agents_downloads", expires_in: 1.day) do
      top_agents_downloads_query(id, "podcast_id")
    end
  end

  def other_agents_downloads
    Rails.cache.fetch("#{cache_key_with_version}/other_agents_downloads", expires_in: 1.day) do
      other_agents_downloads_query(id, "podcast_id", top_agents_downloads)
    end
  end

  def agent_download_rollups
    all_agents = top_agents_downloads.merge({other: other_agents_downloads})
    all_agents.to_a.map do |agent|
      {
        label: Rollups::DailyAgent.label_for(agent[0]),
        downloads: agent[1]
      }
    end
  end
end
