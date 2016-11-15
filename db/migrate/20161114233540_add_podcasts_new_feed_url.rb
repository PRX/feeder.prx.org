class AddPodcastsNewFeedUrl < ActiveRecord::Migration
  def change
    add_column :podcasts, :new_feed_url, :string
  end
end
