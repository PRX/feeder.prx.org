class SyncLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :sync_logs do |t|
      t.string :feeder_type, null: false
      t.bigint :feeder_id, null: false

      t.string :external_id

      t.datetime :sync_completed_at

      t.datetime :created_at
    end
  end
end
