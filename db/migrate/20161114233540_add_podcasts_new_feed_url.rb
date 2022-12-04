class AddPodcastsNewFeedUrl < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :new_feed_url, :string
  end
end
