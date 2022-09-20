# frozen_string_literal: true

class CreateApplePodcastDeliveryFiles < ActiveRecord::Migration
  def change
    create_table :apple_podcast_delivery_files do |t|
      t.integer :episode_id
      t.integer :podcast_delivery_id
      t.string :external_id
      t.string :api_response

      t.timestamps null: false
    end
  end
end
