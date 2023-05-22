class SyncLogHasUniqueState < ActiveRecord::Migration[7.0]
  def change
    reversible do |dir|
      dir.up do
        SyncLog.where.not(id: SyncLog.latest).delete_all
      end
    end

    add_index :sync_logs, [:feeder_type, :feeder_id], unique: true

    add_column :sync_logs, :api_response, :text
    rename_column :sync_logs, :sync_completed_at, :updated_at
  end
end
