class MoveITunesCategoriesToFeed < ActiveRecord::Migration[7.0]
  def up
    add_column :itunes_categories, :feed_id, :integer

    ITunesCategory.all.each do |cat|
      podcast = Podcast.with_deleted.find_by_id(cat.podcast_id)

      # cleanup categories for null/gone podcasts
      if podcast
        cat.update_column(:feed_id, podcast.default_feed.id)
      else
        cat.delete
      end
    end

    remove_column :itunes_categories, :podcast_id
  end

  def down
    add_column :itunes_categories, :podcast_id, :integer

    ITunesCategory.all.each do |cat|
      feed = Feed.with_deleted.find(cat.feed_id)

      # remove categories for non-default feeds
      if feed&.default?
        cat.update_column(:podcast_id, feed.podcast_id)
      else
        cat.delete
      end
    end

    remove_column :itunes_categories, :feed_id
  end
end
