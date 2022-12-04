class CreateMediaResources < ActiveRecord::Migration[4.2]
  def change
    create_table :media_resources do |t|
      t.references :episode, index: true
      t.integer :position
      t.string :type
      t.string :url
      t.string :mime_type
      t.integer :file_size
      t.boolean :is_default
      t.string :medium
      t.string :expression
      t.integer :bitrate
      t.integer :framerate
      t.decimal :samplingrate
      t.integer :channels
      t.decimal :duration
      t.integer :height
      t.integer :width
      t.string :lang

      t.timestamps null: false
    end
  end
end
