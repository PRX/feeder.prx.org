class ITunesImage < ActiveRecord::Base
  belongs_to :podcast

  validates :height, :width, numericality: {
    less_than_or_equal_to: 3000,
    greater_than_or_equal_to: 1400
  }

  validates :height, numericality: { equal_to: -> (image) { image.width } }

  include ImageFile
end
