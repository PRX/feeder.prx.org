class FeedImage < ActiveRecord::Base
  include ImageFile

  belongs_to :podcast

  # validates :link, :title, presence: true

  # validates :width, numericality: { less_than_or_equal_to: 144 }
  # validates :height, numericality: { less_than_or_equal_to: 400 }
end
