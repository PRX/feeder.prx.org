class AddTitleToFeedImages < ActiveRecord::Migration[4.2]
  def change
    add_column :feed_images, :title, :string
  end
end
