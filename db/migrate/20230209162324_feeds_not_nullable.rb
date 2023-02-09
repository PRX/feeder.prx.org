class FeedsNotNullable < ActiveRecord::Migration[7.0]
  def change
    change_column :apple_credentials, :public_feed_id, :bigint, null: false
    change_column :apple_credentials, :private_feed_id, :bigint, null: false
  end
end
