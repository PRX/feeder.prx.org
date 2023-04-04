class DeliveryFilesHaveUploadedState < ActiveRecord::Migration[7.0]
  def up
    rename_column :apple_podcast_delivery_files, :uploaded, :api_marked_as_uploaded
    add_column :apple_podcast_delivery_files, :upload_operations_complete, :boolean, default: false

    Apple::PodcastDeliveryFile.with_deleted.where(api_marked_as_uploaded: true).update_all(upload_operations_complete: true)
  end

  def down
    rename_column :apple_podcast_delivery_files, :api_marked_as_uploaded, :uploaded
    remove_column :apple_podcast_delivery_files, :upload_operations_complete
  end
end
