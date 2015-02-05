class ChangeImageTables < ActiveRecord::Migration
  def change
    drop_table :images do |t|
    end

    create_table :feed_images do |t|
      t.string :url
      t.string :link
      t.string :description
      t.integer :height
      t.integer :width
      t.references :podcast
    end

    create_table :itunes_images do |t|
      t.string :url
      t.references :podcast
    end

    add_index :feed_images, :podcast_id
    add_index :itunes_images, :podcast_id
  end
end
