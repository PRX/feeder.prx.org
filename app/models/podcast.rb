class Podcast < ActiveRecord::Base
  has_one :itunes_image
  has_one :feed_image

  has_many :episodes
  has_many :itunes_categories

  validates_presence_of :itunes_image, :feed_image

  after_update do
    DateUpdater.last_build_date(self)
  end

  acts_as_paranoid

  def web_master
    ENV['FEEDER_WEB_MASTER'] || 'prxhelp@prx.org (PRX)'
  end

  def generator
    (ENV['FEEDER_GENERATOR'] || "PRX Feeder") + "v#{Feeder::VERSION}"
  end
end
