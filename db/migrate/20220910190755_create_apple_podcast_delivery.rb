# frozen_string_literal: true

class CreateApplePodcastDelivery < ActiveRecord::Migration
  def change
    create_table :apple_podcast_deliveries do |t|
      t.integer :episode_id
      t.integer :podcast_container_id
      t.string :external_id
      t.string :status
      t.string :api_response

      t.timestamps null: false
    end
  end
end
