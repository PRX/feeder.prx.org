class AddExcludeState < ActiveRecord::Migration[4.2]
  def change
    add_column :feeds, :exclude_tags, :text
  end
end
