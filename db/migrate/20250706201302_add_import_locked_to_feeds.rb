class AddImportLockedToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :import_locked, :boolean, default: true, null: false
    execute "UPDATE feeds SET import_locked = true"
  end
end
