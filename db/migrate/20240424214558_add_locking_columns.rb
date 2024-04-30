class AddLockingColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :episodes, :lock_version, :integer, null: false, default: 0
    add_column :feeds, :lock_version, :integer, null: false, default: 0
    add_column :podcasts, :lock_version, :integer, null: false, default: 0
  end
end
