class AddAppleShowIdToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :apple_show_id, :string
    add_index :feeds, :apple_show_id

    reversible do |dir|
      dir.up do
        Feeds::AppleSubscription.all.each do |feed|
          apple_id = feed.apple_sync_log&.external_id
          feed.update_attribute!(:apple_show_id, apple_id)
        end
      end
    end
  end
end
