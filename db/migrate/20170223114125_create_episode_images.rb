class CreateEpisodeImages < ActiveRecord::Migration
  def change
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
  end
end
