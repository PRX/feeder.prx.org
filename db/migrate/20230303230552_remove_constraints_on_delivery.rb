class RemoveConstraintsOnDelivery < ActiveRecord::Migration[7.0]
  def change
    remove_index :apple_podcast_deliveries, name: "index_apple_podcast_deliveries_on_episode_id", unique: true
    add_index :apple_podcast_deliveries, :episode_id

    remove_index :apple_podcast_deliveries, name: "index_apple_podcast_deliveries_on_podcast_container_id", unique: true
    add_index :apple_podcast_deliveries, :podcast_container_id

    remove_index :apple_podcast_delivery_files, name: "index_apple_podcast_delivery_files_on_podcast_delivery_id", unique: true
    add_index :apple_podcast_delivery_files, :podcast_delivery_id
  end
end
