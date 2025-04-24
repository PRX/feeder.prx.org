class AddUniqueGuidsToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :unique_guids, :boolean, default: false, null: false
  end
end
