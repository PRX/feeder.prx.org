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
end
