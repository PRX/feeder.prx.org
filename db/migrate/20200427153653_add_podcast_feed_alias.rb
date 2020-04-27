class AddPodcastFeedAlias < ActiveRecord::Migration
  def change
    add_column :podcasts, :feed_rss_alias, :string
  end
end
