class CreateFeeds < ActiveRecord::Migration
  def change
    remove_column :podcasts, :max_episodes, :integer

    create_table :feeds do |t|
      t.references :podcast, index: true, foreign_key: true
      t.string :label
      t.string :slug, null: false

      # optional overrides
      t.text :title
      t.string :url
      t.string :path
      t.string :enclosure_prefix
      t.string :enclosure_template
      t.integer :display_episodes_count
      t.integer :display_full_episodes_count

      # optional sub-feed settings
      t.boolean :private, default: true
      t.integer :publish_offset_seconds
      t.text :filter_zones
      t.text :filter_tags
      t.text :audio_format

      t.timestamps null: false
    end

    add_index :feeds, [:podcast_id, :slug], unique: true

    create_table :feed_tokens do |t|
      t.references :feed, index: true, foreign_key: true

      t.string :label
      t.string :token, null: false
      t.datetime :expires_at

      t.timestamps null: false
    end

    add_index :feed_tokens, [:feed_id, :token], unique: true
  end
end
