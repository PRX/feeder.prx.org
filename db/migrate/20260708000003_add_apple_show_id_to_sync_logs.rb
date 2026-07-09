# frozen_string_literal: true

class AddAppleShowIdToSyncLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :sync_logs, :apple_show_id, :string

    remove_index :sync_logs,
      [:integration, :feeder_type, :feeder_id],
      unique: true,
      name: "index_sync_logs_on_integration_and_feeder_type_and_feeder_id"

    add_index :sync_logs,
      [:integration, :feeder_type, :feeder_id, :apple_show_id],
      unique: true,
      nulls_not_distinct: true,
      name: "idx_sync_logs_unique_by_apple_show"
  end
end
