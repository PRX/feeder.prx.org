class CreateApplePodcastContainers < ActiveRecord::Migration
  def change
    create_table :apple_podcast_containers do |t|
      t.integer :episode_id
      t.string :external_id

      t.timestamps null: false
    end
  end
end
