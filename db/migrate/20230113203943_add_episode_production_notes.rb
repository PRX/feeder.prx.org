class AddEpisodeProductionNotes < ActiveRecord::Migration[7.0]
  def change
    add_column :episodes, :production_notes, :text
  end
end
