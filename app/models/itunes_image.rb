class ITunesImage < PodcastImage
  validates :height, :width, numericality: {
    less_than_or_equal_to: 3000,
    greater_than_or_equal_to: 1400
  }, if: ->(i) { i.height && i.width }

  validates :height, numericality: { equal_to: -> (image) { image.width } }, if: ->(i) { i.height }

  def replace_resources!
    podcast.with_lock do
      podcast.itunes_images.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
