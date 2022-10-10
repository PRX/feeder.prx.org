class AddUploadedToPodcastDeliveryFiles < ActiveRecord::Migration
  def change
    add_column :apple_podcast_delivery_files, :uploaded, :boolean, default: false
  end
end
