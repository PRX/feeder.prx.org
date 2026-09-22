class CreateAppleHlsAlternateAssets < ActiveRecord::Migration[7.2]
  def change
    create_table :apple_hls_alternate_assets do |t|
      t.references :episode, null: false, foreign_key: true
      t.references :feeder_podcast, null: false, foreign_key: {to_table: :podcasts}
      t.string :apple_show_id, null: false
      t.string :feeder_guid, null: false
      t.integer :status, null: false
      t.string :staged_alternate_asset_id
      t.string :content_url
      t.datetime :last_checked_at
      t.string :last_error
      t.timestamps

      t.index [:feeder_podcast_id, :apple_show_id, :feeder_guid], unique: true, name: "idx_apple_hls_alternate_assets_unique_key"
    end
  end
end
