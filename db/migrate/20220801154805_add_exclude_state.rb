class AddEpisodeExcludeState < ActiveRecord::Migration
  def change
    add_column :feeds, :exclude_tags, :text
  end
end
