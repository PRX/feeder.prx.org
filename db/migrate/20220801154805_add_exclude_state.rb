class AddExcludeState < ActiveRecord::Migration
  def change
    add_column :feeds, :exclude_tags, :text
  end
end
