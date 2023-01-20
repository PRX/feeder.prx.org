class CreateApplePodcastContainers < ActiveRecord::Migration[7.0]
  def change
    create_table :apple_podcast_containers do |t|
      t.integer :episode_id
      t.string :external_id
      t.string :api_response

      t.timestamps null: false
    end
  end
end
