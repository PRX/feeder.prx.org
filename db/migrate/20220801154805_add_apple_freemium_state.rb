class AddAppleFreemiumState < ActiveRecord::Migration
  def change
    add_column :feeds, :exclude_tags, :text
    change_column :feeds, :include_tags, :text
  end
end
