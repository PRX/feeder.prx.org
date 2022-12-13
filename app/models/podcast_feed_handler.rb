class PodcastFeedHandler
  FEED_ATTRS = %w( complete copyright description explicit keywords language
                   subtitle summary title update_frequency update_period
                   author managing_editor new_feed_url owners ).freeze

  attr_accessor :podcast, :default_feed, :feed

  def self.create_from_feed!(feed)
    update_from_feed!(Podcast.new, feed)
  end

  def self.update_from_feed!(podcast, feed = nil)
    new(podcast).update_from_feed!(feed)
  end

  def initialize(podcast)
    self.podcast = podcast
    podcast.set_defaults
    self.default_feed = podcast.default_feed
  end

  def update_from_feed!(feed)
    Podcast.transaction do
      podcast.lock!
      update_from_feed(feed)
      podcast.save!
    end
    podcast
  end

  def update_from_feed(feed)
    self.feed = feed
    update_feed_attributes
    update_images
    update_categories
  end

  def update_feed_attributes
    fa = feed.attributes.with_indifferent_access
    podcast.attributes = fa.slice(*FEED_ATTRS).with_indifferent_access

    {feed_url: :source_url, url: :link}.each do |k, v|
      podcast.send("#{v}=", fa[k.to_s])
    end

    podcast.path ||= fa['feedburner_name']
  end

  def update_images
    fa = feed.attributes.with_indifferent_access
    default_feed.feed_image_file = fa[:thumb_url]
    default_feed.itunes_image_file = fa[:image_url]
  end

  def update_categories
    itunes_cats = {}
    cats = []
    feed.categories.each do |cat|
      if ITunesCategoryValidator.category?(cat)
        itunes_cats[cat] ||= []
      elsif parent_cat = ITunesCategoryValidator.subcategory?(cat)
        itunes_cats[parent_cat] ||= []
        itunes_cats[parent_cat] << cat
      else
        cats << cat
      end
    end

    # delete and update existing itunes_categories
    podcast.itunes_categories.each do |icat|
      if itunes_cats.key?(icat.name)
        subs = itunes_cats.delete(icat.name).sort.uniq
        icat.update!(subcategories: subs)
      else
        icat.destroy!
      end
    end

    # create missing itunes_categories
    itunes_cats.each_key do |cat|
      subs = itunes_cats[cat].sort.uniq
      podcast.itunes_categories.build(name: cat, subcategories: subs)
    end

    podcast.categories = cats
  end
end
