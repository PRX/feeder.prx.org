class RemoveEpisodesImageUrl < ActiveRecord::Migration
  def change
    remove_column :episodes, :image_url
  end
end
