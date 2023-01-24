class AddFeedEnclosurePrefix < ActiveRecord::Migration[4.2]
  def up
    add_column :feeds, :enclosure_prefix, :string
    add_column :feeds, :enclosure_template, :string

    Podcast.with_deleted.each do |podcast|
      next unless (feed = podcast.default_feed)

      feed.enclosure_prefix = podcast.enclosure_prefix
      feed.enclosure_template = podcast.enclosure_template
      feed.save!
    end

    remove_column :podcasts, :enclosure_prefix
    remove_column :podcasts, :enclosure_template
  end

  def down
    add_column :podcasts, :enclosure_prefix, :string
    add_column :podcasts, :enclosure_template, :string

    Podcast.with_deleted.each do |podcast|
      next unless (feed = podcast.default_feed)

      podcast.enclosure_prefix = feed.enclosure_prefix
      podcast.enclosure_template = feed.enclosure_template
      podcast.save!
    end

    remove_column :feeds, :enclosure_prefix
    remove_column :feeds, :enclosure_template
  end
end
