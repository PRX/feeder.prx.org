class CreateFeeds < ActiveRecord::Migration
  def change
    create_table :feeds do |t|
      t.references :podcast, index: true, foreign_key: true
      t.string :name
      t.text :overrides

      t.timestamps null: false
    end
  end
end
