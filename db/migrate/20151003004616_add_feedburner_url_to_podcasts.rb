class AddFeedburnerUrlToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :feedburner_url, :string
  end
end
