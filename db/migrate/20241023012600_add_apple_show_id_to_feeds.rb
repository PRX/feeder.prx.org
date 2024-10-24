class AddAppleShowIdToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :apple_show_id, :string
    add_index :feeds, :apple_show_id
  end
end
