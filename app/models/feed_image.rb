class FeedImage < PodcastImage
  def replace_resources!
    podcast.with_lock do
      podcast.feed_images.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
