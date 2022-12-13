class AddFeedburnerUrlToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :feedburner_url, :string
  end
end
