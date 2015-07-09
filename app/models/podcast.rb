class Podcast < ActiveRecord::Base
  has_one :itunes_image
  has_one :feed_image

  has_many :episodes
  has_many :itunes_categories

  validates :itunes_image, :feed_image, presence: true
  validates :path, :prx_uri, uniqueness: true

  acts_as_paranoid

  after_update do
    DateUpdater.last_build_date(self)
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
    PublishFeedJob.perform_later(self)
  end

  def web_master
    ENV['FEEDER_WEB_MASTER']
  end

  def generator
    ENV['FEEDER_GENERATOR']
  end
end
