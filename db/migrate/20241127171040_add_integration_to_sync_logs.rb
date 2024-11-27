class AddIntegrationToSyncLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :sync_logs, :integration, :integer

    execute(<<~SQL
      UPDATE sync_logs
      SET integration = 0
    SQL
           )

    remove_index :sync_logs, [:feeder_type, :feeder_id], unique: true
    add_index :sync_logs, [:integration, :feeder_type, :feeder_id], unique: true
  end
end
