class ChangePRXIdToUri < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :prx_uri, :string
    add_index :episodes, :prx_uri, unique: true
    remove_column :episodes, :prx_id, :integer

    add_column :podcasts, :prx_uri, :string
    add_index :podcasts, :prx_uri, unique: true
    remove_column :podcasts, :prx_id, :integer
  end
end
