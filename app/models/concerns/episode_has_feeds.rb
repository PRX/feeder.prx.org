require "active_support/concern"

module EpisodeHasFeeds
  extend ActiveSupport::Concern

  included do
    has_many :episodes_feeds, dependent: :delete_all
    has_many :feeds, through: :episodes_feeds

    after_initialize :set_default_feeds, if: :new_record?
    before_validation :set_default_feeds, if: :new_record?

    # NOTE: this DOES NOT apply the display_episodes_count
    scope :in_feed, ->(feed) do
      Episode.joins(:episodes_feeds)
        .where(episodes_feeds: {feed: feed})
        .published_by(feed.episode_offset_seconds.to_i)
    end

    # NOTE: this DOES NOT apply the display_episodes_count
    scope :in_default_feed, -> { joins(:feeds).where(feeds: {slug: nil}).published }
  end

  def set_default_feeds
    if feeds.blank?
      self.feeds = (podcast&.feeds || []).filter_map do |feed|
        feed if feed.default? || feed.apple?
      end
    end
  end

  def in_feed?(feed)
    published_by?(feed.episode_offset_seconds.to_i) && episodes_feeds.where(feed: feed).any?
  end

  def in_default_feed?
    published? && feeds.where(slug: nil).any?
  end

  def feed_slugs
    feeds.pluck(:slug).map { |s| s || "default" }
  end

  def feed_slugs=(slugs)
    self.feeds = (podcast&.feeds || []).filter_map do |feed|
      feed if slugs.try(:include?, feed.slug || "default")
    end
  end
end
