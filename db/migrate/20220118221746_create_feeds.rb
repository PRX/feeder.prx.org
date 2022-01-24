class CreateFeeds < ActiveRecord::Migration
  DEFAULT_FILE_NAME = 'feed-rss.xml'

  def up
    create_table :feeds do |t|
      t.references :podcast, index: true, foreign_key: true
      t.string :slug, null: true
      t.string :file_name, null: false
      t.boolean :private, default: true

      # title stays with the podcast, but can be overriden here
      t.text :title

      # feed settings (porting from the podcast)
      t.string :url
      t.string :new_feed_url
      t.integer :display_episodes_count
      t.integer :display_full_episodes_count

      # additional feed settings
      t.integer :episode_offset_seconds
      t.text :filter_zones
      t.text :filter_tags
      t.text :audio_format

      t.timestamps null: false
    end

    add_index :feeds, :podcast_id, unique: true, where: 'slug IS NULL', name: :index_feeds_on_podcast_id_default
    add_index :feeds, [:podcast_id, :slug], unique: true, where: 'slug IS NOT NULL'

    create_table :feed_tokens do |t|
      t.references :feed, index: true, foreign_key: true

      t.string :label
      t.string :token, null: false
      t.datetime :expires_at

      t.timestamps null: false
    end

    add_index :feed_tokens, [:feed_id, :token], unique: true

    # create default feeds
    Podcast.with_deleted.each do |podcast|
      feed = podcast.feeds.new
      feed.slug = nil
      feed.file_name = podcast.feed_rss_alias || DEFAULT_FILE_NAME
      feed.private = false
      feed.url = podcast.url
      feed.new_feed_url = podcast.new_feed_url
      feed.display_episodes_count = podcast.display_episodes_count
      feed.display_full_episodes_count = podcast.display_full_episodes_count
      feed.save!
    end

    # cleanup moved columns
    remove_column :podcasts, :feed_rss_alias
    remove_column :podcasts, :url
    remove_column :podcasts, :new_feed_url
    remove_column :podcasts, :display_episodes_count
    remove_column :podcasts, :display_full_episodes_count
  end

  def down
    add_column :podcasts, :feed_rss_alias, :string
    add_column :podcasts, :url, :string
    add_column :podcasts, :new_feed_url, :string
    add_column :podcasts, :display_episodes_count, :integer
    add_column :podcasts, :display_full_episodes_count, :integer

    # copy from default feeds
    Feed.where(slug: nil).each do |feed|
      podcast = feed.podcast
      podcast.feed_rss_alias = feed.file_name unless feed.file_name == DEFAULT_FILE_NAME
      podcast.url = feed.url
      podcast.new_feed_url = feed.new_feed_url
      podcast.display_episodes_count = feed.display_episodes_count
      podcast.display_full_episodes_count = feed.display_full_episodes_count
      podcast.save!
    end

    drop_table :feed_tokens
    drop_table :feeds
  end
end
