require 'podcast'

class PodcastFeedHandler
  FEED_ATTRS = %w( complete copyright description explicit keywords language
    subtitle summary title update_frequency update_period
    author managing_editor new_feed_url owners ).freeze

  attr_accessor :podcast, :feed

  def self.create_from_feed!(feed)
    update_from_feed!(Podcast.new, feed)
  end

  def self.update_from_feed!(podcast, feed = nil)
    new(podcast).update_from_feed!(feed)
  end

  def initialize(podcast)
    self.podcast = podcast
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
    update_attributes
    update_images
    update_categories
  end

  def update_attributes
    fa = feed.attributes.with_indifferent_access
    podcast.attributes = fa.slice(*FEED_ATTRS).with_indifferent_access

    {feed_url: :source_url, url: :link}.each do |k,v|
      podcast.send("#{v}=", fa[k.to_s])
    end

    podcast.path ||= fa['feedburner_name']
  end

  def update_images
    fa = feed.attributes.with_indifferent_access
    { feed: :thumb_url, itunes: :image_url }.each do |type, url|
      if fa[url]
        save_image(podcast, type, fa[url])
      elsif i = podcast.send("#{type}_image")
        i.destroy
      end
    end
  end

  def save_image(podcast, type, url)
    if i = podcast.send("#{type}_image")
      i.update_attributes!(url: url)
    else
      podcast.send("build_#{type}_image", url: url)
    end
  end

  def update_categories
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
    podcast.itunes_categories.each do |icat|
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
      podcast.itunes_categories.build(name: cat, subcategories: subs)
    end

    podcast.categories = cats
  end
end
