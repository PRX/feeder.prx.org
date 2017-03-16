class RefactorImages < ActiveRecord::Migration
  def change

    create_table :podcast_images do |t|
      t.references :podcast, index: true
      t.string :type
      t.string :guid, index: { unique: true }
      t.string :url
      t.string :link
      t.string :original_url
      t.string :description
      t.string :title
      t.string :format
      t.integer :height
      t.integer :width
      t.integer :size
    end

    execute "INSERT into podcast_images (guid, type, original_url, url, podcast_id, format, width, height, size, title, link, description, updated_at, created_at, status) SELECT uuid_generate_v4(), 'FeedImage', url, url, podcast_id, format, width, height, size, title, link, description, now(), now(), 3 FROM feed_images"
    execute "INSERT into podcast_images (guid, type, original_url, url, podcast_id, format, width, height, size, title, link, description, updated_at, created_at, status) SELECT uuid_generate_v4(), 'ITunesImage', url, url, podcast_id, format, width, height, size, NULL, NULL, NULL, now(), now(), 3 FROM itunes_images"
  end
end
