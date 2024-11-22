class AddFooterToFeeds < ActiveRecord::Migration[7.2]
  def change
    add_column :feeds, :episode_footer, :string
  end
end
