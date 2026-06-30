class DropSourceFetchCountFromPodcastContainers < ActiveRecord::Migration[7.2]
  def change
    remove_column :apple_podcast_containers, :source_fetch_count, :integer, default: 0, null: false
  end
end
