class AddPublishedToEpisode < ActiveRecord::Migration[4.2]
  def change
    add_column :episodes, :published_at, :timestamp
    add_index :episodes, [:published_at, :podcast_id]
  end
end
