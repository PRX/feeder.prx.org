class FeedImage < ApplicationRecord
  include ImageFile
  include FeedImageFile

  def replace_resources!
    feed&.with_lock do
      FeedImage.where(feed_id: feed_id).where.not(id: id).touch_all(:replaced_at, :deleted_at)
    end
  end
end
