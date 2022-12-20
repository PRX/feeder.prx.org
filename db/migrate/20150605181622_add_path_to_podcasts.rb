class AddPathToPodcasts < ActiveRecord::Migration[4.2]
  def change
    add_column :podcasts, :path, :string
  end
end
