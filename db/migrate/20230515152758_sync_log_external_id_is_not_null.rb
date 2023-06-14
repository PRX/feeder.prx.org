class SyncLogExternalIdIsNotNull < ActiveRecord::Migration[7.0]
  def change
    change_column_null :sync_logs, :external_id, false
  end
end
