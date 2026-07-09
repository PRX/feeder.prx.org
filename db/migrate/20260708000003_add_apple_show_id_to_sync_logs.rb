# frozen_string_literal: true

class AddAppleShowIdToSyncLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :sync_logs, :apple_show_id, :string
  end
end
