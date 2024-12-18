class RenameAppleEpisodeDeliveryStatusToEpisodeDeliveryStatus < ActiveRecord::Migration[7.2]
  def up
    rename_table :apple_episode_delivery_statuses, :integrations_episode_delivery_statuses
    add_column :integrations_episode_delivery_statuses, :integration, :integer
    execute(<<~SQL
      UPDATE integrations_episode_delivery_statuses
      SET integration = 0
    SQL
           )
  end

  def down
    rename_table :integrations_episode_delivery_statuses, :apple_episode_delivery_statuses
    remove_column :apple_episode_delivery_statuses, :integration
  end
end
