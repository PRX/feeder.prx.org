class Image < ActiveRecord::Base
  belongs_to :imageable, polymorphic: true

  validates :url, presence: true
  validates :link, presence: true
  validates :title, presence: true
  validates :imageable, presence: true
end
