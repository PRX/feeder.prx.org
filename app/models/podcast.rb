class Podcast < ActiveRecord::Base
  has_one :itunes_image, class_name: :Image, as: :imageable
  has_one :channel_image, class_name: :Image, as: :imageable

  has_many :episodes
  has_many :itunes_categories

  after_update do
    DateUpdater.last_build_date(self)
  end
end
