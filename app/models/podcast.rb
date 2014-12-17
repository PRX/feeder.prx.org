class Podcast < ActiveRecord::Base
  has_one :image, as: :imageable
  has_many :episodes
end
