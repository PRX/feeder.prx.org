class RemoveDeliveryDeliveryFileApiResponse < ActiveRecord::Migration[7.0]
  def change
    remove_column :apple_podcast_delivery_files, :api_response
    remove_column :apple_podcast_deliveries, :api_response
  end
end
