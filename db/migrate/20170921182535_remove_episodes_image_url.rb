class RemoveEpisodesImageUrl < ActiveRecord::Migration[4.2]
  def change
    remove_column :episodes, :image_url
  end
end
