class RefactorImages < ActiveRecord::Migration
  def change
    execute "INSERT into feed_images (url, podcast_id, format, width, height, size) SELECT url, podcast_id, format, width, height, size FROM itunes_images"
    rename_table :feed_images, :podcast_images
    add_column :podcast_images, :guid, :string
    add_index :podcast_images, :guid, unique: true

    add_column :podcast_images, :original_url, :string
    add_column :podcast_images, :type, :string
  end
end
