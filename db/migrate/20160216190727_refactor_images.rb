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

    execute 'INSERT into podcast_images (url, podcast_id, format, width, height, size) SELECT url, podcast_id, format, width, height, size FROM itunes_images'
    execute 'INSERT into podcast_images (url, podcast_id, format, width, height, size) SELECT url, podcast_id, format, width, height, size FROM feed_images'
  end
end
