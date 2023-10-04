class AddFetchCountToPodcastContainer < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_podcast_containers, :source_fetch_count, :integer, default: 0, null: false
  end
end
