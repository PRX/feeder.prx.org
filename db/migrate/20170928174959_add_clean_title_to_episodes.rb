class AddCleanTitleToEpisodes < ActiveRecord::Migration[4.2]
  def up
    add_column :episodes, :clean_title, :text
  end

  def down
    remove_column :episodes, :clean_title
  end
end
