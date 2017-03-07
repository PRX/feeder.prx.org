class CreateEpisodeImages < ActiveRecord::Migration
  def up
    create_table :episode_images do |t|
      t.references :episode, index: true
      t.string :type
      t.integer :status
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
      t.timestamps null: false
    end

    enable_extension 'uuid-ossp' if Rails.env.test? || Rails.env.development?
    execute %{
      INSERT into episode_images (guid, original_url, url, episode_id, status, created_at, updated_at)
      SELECT uuid_generate_v4(), image_url, image_url, id, 3, created_at, updated_at
      FROM episodes
      WHERE image_url is not null
    }
    disable_extension 'uuid-ossp' if Rails.env.test? || Rails.env.development?
  end

  def down
    drop_table :episode_images
  end
end
