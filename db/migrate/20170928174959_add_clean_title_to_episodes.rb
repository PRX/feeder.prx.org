class AddCleanTitleToEpisodes < ActiveRecord::Migration
  def up
    add_column :episodes, :clean_title, :text
  end

  def down
    remove_column :episodes, :clean_title
  end
end
