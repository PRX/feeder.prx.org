class AddEpisodeTags < ActiveRecord::Migration[4.2]
  def up
    add_column :episodes, :season_number, :integer
    add_column :episodes, :episode_number, :integer
    add_column :episodes, :itunes_type, :string, default: "full"
    execute "UPDATE episodes SET itunes_type = 'full'"
  end

  def down
    remove_column :episodes, :season_number
    remove_column :episodes, :episode_number
    remove_column :episodes, :itunes_type
  end
end
