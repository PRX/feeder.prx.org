class AddPodcastAppleConfigUniqueConstraint < ActiveRecord::Migration[7.0]
  def change
    add_index :apple_configs, [:podcast_id], unique: true
  end
end
