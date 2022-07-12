class Podcast < BaseModel
  FEED_GETTERS = %i(url new_feed_url display_episodes_count display_full_episodes_count enclosure_prefix enclosure_template feed_image itunes_image)
  FEED_SETTERS = %i(url= new_feed_url= display_episodes_count= display_full_episodes_count= enclosure_prefix= enclosure_template= feed_image= itunes_image=)

  include TextSanitizer

  serialize :categories, JSON
  serialize :keywords, JSON
  serialize :restrictions, JSON

  has_one :default_feed, -> { default }, class_name: 'Feed', validate: true, autosave: true
  has_many :feeds, dependent: :destroy

  has_many :episodes, -> { order('published_at desc') }
  has_many :itunes_categories, autosave: true, dependent: :destroy
  has_many :tasks, as: :owner

  validates :path, :prx_uri, :source_url, uniqueness: true, allow_nil: true
  validates :restrictions, media_restrictions: true
  validates :explicit, inclusion: { in: %w(true false) }, allow_nil: false

  # these keep changing - so just translate to the current accepted values
  EXPLICIT_ALIASES = {
    '' => 'false',
    'no' => 'false',
    'clean' => 'false',
    false => 'false',
    'yes' => 'true',
    'explicit' => 'true',
    true => 'true'
  }.freeze

  acts_as_paranoid

  before_validation :set_defaults, :sanitize_text

  scope :published, -> { where('published_at IS NOT NULL AND published_at <= now()') }

  def self.by_prx_series(series)
    series_uri = series.links['self'].href
    Podcast.find_by(prx_uri: series_uri)
  end

  def set_defaults
    self.default_feed ||= feeds.new(private: false)
    self.explicit ||= 'false'
  end

  def explicit=(value)
    super(EXPLICIT_ALIASES[value] || value)
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
    URI.parse(uri || '').path.split('/').last.to_i
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
    self.owner_name = owner['name']
    self.owner_email = owner['email']
  end

  def author=(a)
    author = a || {}
    self.author_name = author['name']
    self.author_email = author['email']
  end

  def managing_editor=(me)
    managing_editor = me || {}
    self.managing_editor_name = managing_editor['name']
    self.managing_editor_email = managing_editor['email']
  end

  def managing_editor
    return nil unless (managing_editor_name || managing_editor_email)
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
    ENV['FEEDER_WEB_MASTER']
  end

  def generator
    ENV['FEEDER_GENERATOR']
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
    serial_order ? 'serial' : 'episodic'
  end

  def sanitize_text
    self.description = sanitize_white_list(description) if description_changed?
    self.subtitle = sanitize_text_only(subtitle) if subtitle_changed?
    self.summary = sanitize_links_only(summary) if summary_changed?
    self.title = sanitize_text_only(title) if title_changed?
  end

  def feeder_cdn_host
    ENV['FEEDER_CDN_HOST']
  end

  def feeder_cdn_private_host
    ENV['FEEDER_CDN_PRIVATE_HOST']
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
