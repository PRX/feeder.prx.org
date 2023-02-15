class ITunesImage < ApplicationRecord
  include ImageFile
  include FeedImageFile

  validates :height, :width, numericality: {
    less_than_or_equal_to: 3000,
    greater_than_or_equal_to: 1400
  }, if: ->(i) { i.height && i.width }

  validates :height, numericality: {equal_to: ->(image) { image.width }}, if: ->(i) { i.height }

  def replace_resources!
    ITunesImage.where(feed_id: feed_id).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
