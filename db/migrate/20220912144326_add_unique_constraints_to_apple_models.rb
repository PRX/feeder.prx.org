# frozen_string_literal: true

class AddUniqueConstraintsToAppleModels < ActiveRecord::Migration[7.0]
  def change
    add_index :apple_podcast_containers, :episode_id, unique: true
    add_index :apple_podcast_deliveries, :episode_id, unique: true
  end
end
