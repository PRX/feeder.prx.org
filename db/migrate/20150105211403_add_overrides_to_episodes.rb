class AddOverridesToEpisodes < ActiveRecord::Migration
  def change
    add_column :episodes, :overrides, :text
  end
end
