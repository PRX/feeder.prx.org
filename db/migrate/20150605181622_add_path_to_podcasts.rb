class AddPathToPodcasts < ActiveRecord::Migration
  def change
    add_column :podcasts, :path, :string
  end
end
