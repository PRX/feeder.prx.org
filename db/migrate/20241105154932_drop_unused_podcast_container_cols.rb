class DropUnusedPodcastContainerCols < ActiveRecord::Migration[7.2]
  def change
    remove_column :apple_podcast_containers, :source_url, :string
    remove_column :apple_podcast_containers, :source_filename, :string
    remove_column :apple_podcast_containers, :source_size, :bigint
    remove_column :apple_podcast_containers, :enclosure_url, :string
  end
end
