class AddTypeToFeeds < ActiveRecord::Migration[7.0]
  def change
    add_column :feeds, :type, :string

    Feed.where(id: Apple::Config.select(:feed_id)).update_all(type: "Feed::AppleSubscription")
  end
end
