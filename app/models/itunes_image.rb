class ITunesImage < ApplicationRecord
  include ImageFile
  include FeedImageFile

  validates :height, :width, numericality: {greater_than_or_equal_to: 1400, less_than_or_equal_to: 3000}, if: :status_complete?
  validates :height, comparison: {equal_to: :width}, if: :status_complete?

  def replace_resources!
    ITunesImage.where(feed_id: feed_id).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
