class CreateAppleShowFeedBindings < ActiveRecord::Migration[7.2]
  def change
    create_table :apple_show_feed_bindings do |t|
      t.references :feed, null: false, foreign_key: true, index: {unique: true}
      t.string :apple_show_id, null: false
      t.timestamps
    end
  end
end
