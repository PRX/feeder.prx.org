class MoveDescriptionToFeed < ActiveRecord::Migration[4.2]
  def up
    add_column :feeds, :subtitle, :text
    add_column :feeds, :description, :text
    add_column :feeds, :summary, :text

    Podcast.with_deleted.each do |podcast|
      next unless feed = podcast.default_feed

      feed.subtitle = podcast.subtitle
      feed.description = podcast.description
      feed.summary = podcast.summary
      feed.save!
    end

    remove_column :podcasts, :subtitle
    remove_column :podcasts, :description
    remove_column :podcasts, :summary
  end

  def down
    add_column :podcasts, :subtitle, :text
    add_column :podcasts, :description, :text
    add_column :podcasts, :summary, :text

    Podcast.with_deleted.each do |podcast|
      next unless feed = podcast.default_feed

      podcast.subtitle = feed.subtitle
      podcast.description = feed.description
      podcast.summary = feed.summary
      podcast.save!
    end

    remove_column :feeds, :subtitle
    remove_column :feeds, :description
    remove_column :feeds, :summary
  end
end
