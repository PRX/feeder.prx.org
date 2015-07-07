class CreateITunesCategories < ActiveRecord::Migration
  def change
    create_table :itunes_categories do |t|
      t.timestamps
      t.references :podcast
      t.string :name, null: false
      t.string :subcategories
    end
  end
end
