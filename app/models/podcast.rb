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

  scope :published, -> { where('published_at IS NOT NULL AND published_at <= now()') }

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

  def self.create_from_feed!(feed)
    podcast = new.update_from_feed(feed)
    podcast.save!
    podcast
  end

  FEED_ATTRS = %w( complete copyright description explicit keywords language
    subtitle summary title update_frequency update_period
    author managing_editor new_feed_url owners ).freeze

  def update_from_feed(feed_resource)
    feed = feed_resource.attributes

    self.attributes = feed.slice(*FEED_ATTRS)

    {feed_url: :source_url, url: :link}.each do |k,v|
      send("#{v}=", feed[k.to_s])
    end

    self.path ||= feed['feedburner_name']

    update_images(feed)
    update_categories(feed_resource)

    self
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

  def save_image(type, url)
    if i = send("#{type}_image")
      i.update_attributes!(url: url)
    else
      send("build_#{type}_image", url:url)
    end
  end

  def update_images(feed)
    { feed: :thumb_url, itunes: :image_url }.each do |type, url|
      if feed[url]
        save_image(type, feed[url])
      elsif i = send("#{type}_image")
        i.destroy
      end
    end
  end

  def update_categories(feed)
    itunes_cats = {}
    cats = []
    feed.categories.each do |cat|
      if ITunesCategoryValidator.is_category?(cat)
        itunes_cats[cat] ||= []
      elsif parent_cat = ITunesCategoryValidator.is_subcategory?(cat)
        itunes_cats[parent_cat] ||= []
        itunes_cats[parent_cat] << cat
      else
        cats << cat
      end
    end

    # delete and update existing itunes_categories
    self.itunes_categories.each do |icat|
      if itunes_cats.key?(icat.name)
        subs = itunes_cats.delete(icat.name).sort.uniq
        icat.update_attributes!(subcategories: subs)
      else
        icat.destroy!
      end
    end

    # create missing itunes_categories
    itunes_cats.keys.each do |cat|
      subs = itunes_cats[cat].sort.uniq
      self.itunes_categories.build(name: cat, subcategories: subs)
    end

    self.categories = cats
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
