# frozen_string_literal: true

class AddExternalShowIdToSyncLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :sync_logs, :external_show_id, :string
  end
end
