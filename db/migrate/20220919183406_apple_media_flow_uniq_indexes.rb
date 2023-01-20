# frozen_string_literal: true

class AppleMediaFlowUniqIndexes < ActiveRecord::Migration[7.0]
  def change
    add_index :apple_podcast_containers, :external_id, unique: true

    add_index :apple_podcast_deliveries, :podcast_container_id, unique: true
    add_index :apple_podcast_deliveries, :external_id, unique: true

    add_index :apple_podcast_delivery_files, :podcast_delivery_id, unique: true
    add_index :apple_podcast_delivery_files, :external_id, unique: true
  end
end
