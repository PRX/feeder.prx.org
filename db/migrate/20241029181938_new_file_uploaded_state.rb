class NewFileUploadedState < ActiveRecord::Migration[7.2]
  def change
    add_column :apple_episode_delivery_statuses, :uploaded, :boolean, default: false
  end
end
