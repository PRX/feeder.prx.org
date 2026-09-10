class AllowNullAssetProcessingAttempts < ActiveRecord::Migration[7.2]
  def change
    change_column_null :integrations_episode_delivery_statuses, :asset_processing_attempts, true
  end
end
