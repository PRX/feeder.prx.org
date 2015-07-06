class Podcast < ActiveRecord::Base
  has_one :itunes_image
  has_one :feed_image

  has_many :episodes
  has_many :itunes_categories

  validates :itunes_image, :feed_image, presence: true
  validates :path, :prx_uri, uniqueness: true

  after_update do
    DateUpdater.last_build_date(self)
  end

  acts_as_paranoid

  def feed_episodes
    items = episodes.order('created_at desc')
    items = episodes.limit(max_episodes) if max_episodes.to_i > 0
    items
  end

  def web_master
    ENV['FEEDER_WEB_MASTER'] || 'prxhelp@prx.org (PRX)'
  end

  def generator
    (ENV['FEEDER_GENERATOR'] || 'PRX Feeder') + " v#{Feeder::VERSION}"
  end
end
