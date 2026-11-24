class CreateLocations < ActiveRecord::Migration[7.2]
  def change
    create_table :locations do |t|
      t.references :owner, polymorphic: true, index: true

      t.string :name
      t.string :rel
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.string :osm
      t.string :country

      t.timestamps
    end
  end
end
