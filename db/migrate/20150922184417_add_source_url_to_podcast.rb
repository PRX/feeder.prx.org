class AddSourceUrlToPodcast < ActiveRecord::Migration
  def change
    add_column :podcasts, :source_url, :string
  end
end
