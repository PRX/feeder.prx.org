class Episode < ActiveRecord::Base
  belongs_to :podcast, touch: true
  has_one :image, as: :imageable

  validates :podcast, presence: true
end
