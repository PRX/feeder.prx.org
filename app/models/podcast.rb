class Podcast < ActiveRecord::Base

  serialize :categories, JSON
  serialize :keywords, JSON

  has_one :itunes_image, autosave: true
  has_one :feed_image, autosave: true

  has_many :episodes
  has_many :itunes_categories, autosave: true
  has_many :tasks, as: :owner

  validates :itunes_image, :feed_image, presence: true
  validates :path, :prx_uri, uniqueness: true, allow_nil: true

  acts_as_paranoid

  after_save do
    DateUpdater.last_build_date(self)
  end

  def self.create_from_feed!(feed)
    podcast = new.update_from_feed(feed)
    podcast.save!
    podcast
  end

  def update_from_feed(feed)
    %w(complete copyright description explicit keywords language managing_editor subtitle summary title update_frequency update_period).each do |at|
      self.try("#{at}=", feed.attributes[at])
    end

    {feed_url: :source_url, url: :link, author: :author_name}.each do |k,v|
      self.try("#{v}=", feed.attributes[k.to_s])
    end

    self.path ||= feed.attributes['feedburner_name']

    if feed.attributes[:owners] && feed.attributes[:owners].size > 0
      owner = feed.attributes[:owners].first
      self.owner_name = owner['name']
      self.owner_email = owner['email']
    end

    update_images(feed)
    update_categories(feed)

    self
  end

  def update_images(feed)
    if self.feed_image
      self.feed_image.update_attributes!(url: feed.attributes[:thumb_url])
    else
      self.build_feed_image(url: feed.attributes[:thumb_url])
    end

    if self.itunes_image
      self.itunes_image.update_attributes!(url: feed.attributes[:image_url])
    else
      self.build_itunes_image(url: feed.attributes[:image_url])
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

    # # create missing itunes_categories
    itunes_cats.keys.each do |cat|
      subs = itunes_cats[cat].sort.uniq
      self.itunes_categories.build(name: cat, subcategories: subs)
    end

    self.categories = cats
  end

  def feed_episodes
    feed = []
    feed_max = max_episodes.to_i
    episodes.includes(:tasks).order('created_at desc').each do |ep|
      feed << ep if ep.include_in_feed?
      break if (feed_max > 0) && (feed.size >= feed_max)
    end
    feed
  end

  def publish!
    DateUpdater.both_dates(self)
    create_publish_task
  end

  def create_publish_task
    publish_task = Tasks::PublishFeedTask.create!(owner: self)
    publish_task.start!
  end

  def web_master
    ENV['FEEDER_WEB_MASTER']
  end

  def generator
    ENV['FEEDER_GENERATOR']
  end
end
