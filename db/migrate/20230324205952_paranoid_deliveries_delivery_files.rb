class ParanoidDeliveriesDeliveryFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_podcast_deliveries, :deleted_at, :timestamp
    add_column :apple_podcast_delivery_files, :deleted_at, :timestamp
  end
end
