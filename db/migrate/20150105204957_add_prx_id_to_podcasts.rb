class AddPrxIdToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :prx_id, :integer
    add_index :podcasts, :prx_id
  end
end
