class AddOverridesToEpisodes < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :overrides, :text
  end
end
