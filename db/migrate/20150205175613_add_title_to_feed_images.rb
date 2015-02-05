class AddTitleToFeedImages < ActiveRecord::Migration
  def change
    add_column :feed_images, :title, :string
  end
end
