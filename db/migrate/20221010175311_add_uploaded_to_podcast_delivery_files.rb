class AddUploadedToPodcastDeliveryFiles < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_podcast_delivery_files, :uploaded, :boolean, default: false
  end
end
