# frozen_string_literal: true

class ScopeSyncLogsByAppleShow < ActiveRecord::Migration[7.2]
  OLD_INDEX = "index_sync_logs_on_integration_and_feeder_type_and_feeder_id"
  NEW_INDEX = "idx_sync_logs_unique_by_apple_show"

  def up
    remove_index :sync_logs, name: OLD_INDEX
    add_index :sync_logs,
      [:integration, :feeder_type, :feeder_id, :apple_show_id],
      unique: true,
      nulls_not_distinct: true,
      name: NEW_INDEX
  end

  def down
    remove_index :sync_logs, name: NEW_INDEX
    add_index :sync_logs,
      [:integration, :feeder_type, :feeder_id],
      unique: true,
      name: OLD_INDEX
  end
end
