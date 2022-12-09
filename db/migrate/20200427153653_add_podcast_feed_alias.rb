class AddPodcastFeedAlias < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :feed_rss_alias, :string
  end
end
