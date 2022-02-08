class AddFeedEnclosurePrefix < ActiveRecord::Migration
  def up
    add_column :feeds, :enclosure_prefix, :string

    Podcast.with_deleted.each do |podcast|
      next unless feed = podcast.default_feed
      feed.enclosure_prefix = podcast.enclosure_prefix
      feed.save!
    end
  end

  def down
    Podcast.with_deleted.each do |podcast|
      next unless feed = podcast.default_feed
      podcast.enclosure_prefix = feed.enclosure_prefix
      podcast.save!
    end

    remove_column :feeds, :enclosure_prefix
  end
end
