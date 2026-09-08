# frozen_string_literal: true

class AddAppleShowIdToAppleDeliveryState < ActiveRecord::Migration[7.2]
  def change
    add_column :apple_podcast_containers, :apple_show_id, :string
    add_index :apple_podcast_containers, :apple_show_id

    add_column :integrations_episode_delivery_statuses, :apple_show_id, :string
    add_index :integrations_episode_delivery_statuses, :apple_show_id
  end
end
