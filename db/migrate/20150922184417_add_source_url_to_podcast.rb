class AddSourceUrlToPodcast < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :source_url, :string
  end
end
