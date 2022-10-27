class FeedImage < BaseModel
  include ImageFile
  include FeedImageFile

  def replace_resources!
    feed.with_lock do
      feed.feed_images.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
