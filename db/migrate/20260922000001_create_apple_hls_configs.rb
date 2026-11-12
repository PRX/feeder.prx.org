class CreateAppleHlsConfigs < ActiveRecord::Migration[7.2]
  def change
    create_table :apple_hls_configs do |t|
      t.references :show_feed_binding, null: false, index: {unique: true}, foreign_key: {to_table: :apple_show_feed_bindings}
      t.boolean :enabled, default: false, null: false
      t.boolean :video_enabled_cache
      t.datetime :last_checked_at
      t.timestamps
    end
  end
end
