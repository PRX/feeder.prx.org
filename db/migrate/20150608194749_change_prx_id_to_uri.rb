class ChangePrxIdToUri < ActiveRecord::Migration
  def change
    add_column :episodes, :prx_uri, :string
    remove_column :episodes, :prx_id

    add_column :podcasts, :prx_uri, :string
    remove_column :podcasts, :prx_id
  end
end
