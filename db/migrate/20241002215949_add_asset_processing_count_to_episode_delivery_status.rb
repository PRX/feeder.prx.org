class AddAssetProcessingCountToEpisodeDeliveryStatus < ActiveRecord::Migration[7.2]
  def change
    add_column :apple_episode_delivery_statuses, :asset_processing_attempts, :integer, default: 0, null: false
  end
end
