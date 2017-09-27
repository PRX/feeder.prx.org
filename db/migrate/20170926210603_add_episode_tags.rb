class AddEpisodeTags < ActiveRecord::Migration
  def up
    add_column :episodes, :season, :integer
    add_column :episodes, :number, :integer
    add_column :episodes, :itunes_type, :string, default: 'full'
    execute "UPDATE episodes SET itunes_type = 'full'"
    execute "UPDATE episodes SET itunes_type = 'bonus' WHERE title LIKE %bonus%"
    execute "UPDATE episodes SET itunes_type = 'trailer' WHERE title LIKE %trailer%"
  end

  def down
    remove_column :episodes, :season
    remove_column :episodes, :number
    remove_column :episodes, :itunes_type
  end
end
