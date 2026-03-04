class CreatePersons < ActiveRecord::Migration[7.2]
  def change
    create_table :persons do |t|
      t.references :owner, polymorphic: true, index: true

      t.string :name
      t.string :role
      t.string :organization
      t.string :href

      t.timestamps
    end
  end
end
