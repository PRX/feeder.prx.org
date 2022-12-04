class AddPRXIdToEpisodes < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :prx_id, :integer
    add_index :episodes, :prx_id
  end
end
