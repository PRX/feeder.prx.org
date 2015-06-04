class ItunesImage < ActiveRecord::Base
  include ImageFile

  belongs_to :podcast

  validates :height, :width, numericality: {
    less_than_or_equal_to: 3000,
    greater_than_or_equal_to: 1400
  }

  validates :height, numericality: { equal_to: -> (image) { image.width } }
end
