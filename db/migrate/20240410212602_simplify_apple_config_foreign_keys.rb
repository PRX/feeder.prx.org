class SimplifyAppleConfigForeignKeys < ActiveRecord::Migration[7.0]
  def up
    Apple::Config.find_each do |ac|
      unless ac[:public_feed_id] == Podcast.find(ac[:podcast_id]).default_feed.id
        raise "Apple::Config[#{ac.id} is not using the podcast.default_feed"
      end
    end

    remove_column :apple_configs, :podcast_id
    remove_column :apple_configs, :public_feed_id
    rename_column :apple_configs, :private_feed_id, :feed_id
  end

  def down
    add_column :apple_configs, :podcast_id, :integer
    add_index :apple_configs, [:podcast_id], unique: true

    add_reference :apple_configs, :public_feed, index: true
    add_foreign_key :apple_configs, :feeds, column: :public_feed_id

    rename_column :apple_configs, :feed_id, :private_feed_id

    Apple::Config.find_each do |ac|
      f = Feed.find(ac.private_feed_id)
      ac.podcast_id = f.podcast.id
      ac.public_feed_id = f.podcast.default_feed.id
      ac.save!(validate: false)
    end

    change_column_null :apple_configs, :public_feed_id, false
  end
end
