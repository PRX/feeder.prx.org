class AddFirstRssPublishedAtToEpisodes < ActiveRecord::Migration[7.2]
  def change
    add_column :episodes, :first_rss_published_at, :timestamp

    default_feeds = EpisodesFeed.where(feed_id: Feed.default)
    episodes_in_default_feeds = Episode.published.where(id: default_feeds.select(:episode_id))
    episodes_in_default_feeds.update_all("first_rss_published_at = published_at")
  end
end
