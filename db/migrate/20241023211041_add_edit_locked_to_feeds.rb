class AddEditLockedToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :edit_locked, :boolean
  end
end
