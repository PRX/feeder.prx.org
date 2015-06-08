class AddGuidToEpisodes < ActiveRecord::Migration
  def change
    add_column :episodes, :guid, :string
    add_index :episodes, :guid, unique: true
  end
end
