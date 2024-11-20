class AddFeedEnclosureUpdatedAt < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :enclosure_updated_at, :timestamp
  end
end
