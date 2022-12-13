class AddGuidToEpisodes < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :guid, :string
    add_index :episodes, :guid, unique: true
  end
end
