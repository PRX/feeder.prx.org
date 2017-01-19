class Podcast < BaseModel
  serialize :categories, JSON
  serialize :keywords, JSON

  has_one :itunes_image, autosave: true, dependent: :destroy
  has_one :feed_image, autosave: true, dependent: :destroy

  has_many :episodes, -> { order('published_at desc') }
  has_many :itunes_categories, autosave: true, dependent: :destroy
  has_many :tasks, as: :owner

  validates_associated :itunes_image, :feed_image
  validates :path, :prx_uri, :source_url, uniqueness: true, allow_nil: true

  acts_as_paranoid

  before_validation :set_defaults

  scope :published, -> { where('published_at IS NOT NULL AND published_at <= now()') }

  def self.by_prx_series(series)
    series_uri = series.links['self'].href
    Podcast.with_deleted.find_by(prx_uri: series_uri)
  end

  def set_defaults
    self.enclosure_template ||= enclosure_template_default
  end

  def enclosure_template_default
    "https://#{ENV['DOVETAIL_HOST']}/{slug}/{guid}/{original_filename}"
  end

  def publish_updated
    update_column(:published_at, max_episode_published_at)
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

  def account_id
    URI.parse(prx_account_uri || '').path.split('/').last.to_i
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
    feed = []
    feed_max = display_episodes_count.to_i
    episodes.published.each do |ep|
      feed << ep if ep.include_in_feed?
      break if (feed_max > 0) && (feed.size >= feed_max)
    end
    feed
  end

  def publish!
    create_publish_task
  end

  def create_publish_task
    Tasks::PublishFeedTask.create! do |task|
      task.owner = self
    end.start!
  end

  def web_master
    ENV['FEEDER_WEB_MASTER']
  end

  def generator
    ENV['FEEDER_GENERATOR']
  end

  def base_published_url
    "http://#{feeder_cdn_host}/#{path}"
  end

  def published_url
    "#{base_published_url}/feed-rss.xml"
  end

  # todo: make this per podcast
  def feeder_cdn_host
    ENV['FEEDER_CDN_HOST']
  end
end
