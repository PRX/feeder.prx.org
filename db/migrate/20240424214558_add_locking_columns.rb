class AddLockingColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :episodes, :lock_version, :integer
    add_column :feeds, :lock_version, :integer
    add_column :podcasts, :lock_version, :integer
  end
end
