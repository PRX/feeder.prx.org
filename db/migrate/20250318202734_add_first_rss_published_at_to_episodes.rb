class AddFirstRssPublishedAtToEpisodes < ActiveRecord::Migration[7.2]
  def change
    add_column :episodes, :first_rss_published_at, :timestamp
  end
end
