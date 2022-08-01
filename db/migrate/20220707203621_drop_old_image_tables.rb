class DropOldImageTables < ActiveRecord::Migration
  def up
    drop_table :feed_images
    drop_table :itunes_images
  end

  def down
    create_table :feed_images, force: :cascade do |t|
      t.string :url
      t.string :link
      t.string :description
      t.integer :height
      t.integer :width
      t.integer :podcast_id
      t.string :title
      t.string :format
      t.integer :size
    end

    add_index :feed_images, [:podcast_id], name: :index_feed_images_on_podcast_id, using: :btree

    create_table :itunes_images, force: :cascade do |t|
      t.string :url
      t.integer :podcast_id
      t.string :format
      t.integer :width
      t.integer :height
      t.integer :size
    end

    add_index :itunes_images, [:podcast_id], name: :index_itunes_images_on_podcast_id, using: :btree
  end
end
