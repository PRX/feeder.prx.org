class AddAppleVerifyTokenToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :apple_verify_token, :string
  end
end
