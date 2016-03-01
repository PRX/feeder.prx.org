class ITunesImage < PodcastImage
  validates :height, :width, numericality: {
    less_than_or_equal_to: 3000,
    greater_than_or_equal_to: 1400
  }, if: ->(i) { i.height && i.width }

  validates :height, numericality: { equal_to: -> (image) { image.width } }, if: ->(i) { i.height }
end
