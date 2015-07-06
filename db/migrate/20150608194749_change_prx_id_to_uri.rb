class ChangePrxIdToUri < ActiveRecord::Migration
  def change
    add_column :episodes, :prx_uri, :string
    add_index :episodes, :prx_uri, unique: true
    remove_column :episodes, :prx_id, :integer

    add_column :podcasts, :prx_uri, :string
    add_index :podcasts, :prx_uri, unique: true
    remove_column :podcasts, :prx_id, :integer
  end
end
