class CreateImages < ActiveRecord::Migration[4.2]
  def change
    create_table :images do |t|
      t.timestamps
      t.string :title, null: false
      t.string :url, null: false
      t.string :link, null: false
      t.integer :height
      t.integer :width
      t.text :description
      t.integer :imageable_id
      t.string :imageable_type
    end
  end
end
