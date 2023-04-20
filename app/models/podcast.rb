require "text_sanitizer"

class Podcast < ApplicationRecord
  FEED_ATTRS = %i[subtitle description summary url new_feed_url display_episodes_count display_full_episodes_count enclosure_prefix enclosure_template feed_image itunes_image ready_feed_image ready_itunes_image]
  FEED_GETTERS = FEED_ATTRS.map { |s| [s, "#{s}_was".to_sym, "#{s}_changed?".to_sym] }.flatten
  FEED_SETTERS = FEED_ATTRS.map { |s| "#{s}=".to_sym }

  include TextSanitizer

  serialize :categories, JSON
  serialize :keywords, JSON
  serialize :restrictions, JSON

  has_one :default_feed, -> { default }, class_name: "Feed", validate: true, autosave: true

  has_many :episodes, -> { order("published_at desc") }
  has_many :feeds, dependent: :destroy
  has_many :itunes_categories, validate: true, autosave: true, dependent: :destroy
  has_many :tasks, as: :owner

  accepts_nested_attributes_for :default_feed

  validates :title, presence: true
  validates :link, http_url: true
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

  acts_as_paranoid

  before_validation :set_defaults, :sanitize_text

  scope :published, -> { where("published_at IS NOT NULL AND published_at <= now()") }

  def self.by_prx_series(series)
    series_uri = series.links["self"].href
    Podcast.find_by(prx_uri: series_uri)
  end

  def set_defaults
    set_default_feed
    self.explicit ||= "false"
  end

  def set_default_feed
    self.default_feed ||= feeds.new(private: false)
  end

  def explicit=(value)
    super Podcast::EXPLICIT_ALIASES.fetch(value, value)
  end

  def itunes_category
    itunes_categories.first&.name
  end

  def itunes_category=(value)
    if (cat = itunes_categories[0])
      if cat.name != value
        cat.name = value
        cat.subcategories = []
      end
    else
      itunes_categories.build(name: value)
    end
  end

  def itunes_subcategory
    itunes_categories.first&.subcategories&.first
  end

  def itunes_subcategory=(value)
    if (cat = itunes_categories[0])
      cat.subcategories = [value]
    else
      itunes_categories.build(subcategories: [value])
    end
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

  def feed_episodes
    default_feed.feed_episodes
  end

  def publish!
    create_publish_job unless locked?
  end

  def copy_media(force = false)
    feeds.each { |f| f.copy_media(force) }
  end

  def create_publish_job
    PublishFeedJob.perform_later(self)
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

  def published_url
    "#{base_published_url}/#{default_feed.try(:file_name) || Feed::DEFAULT_FILE_NAME}"
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
