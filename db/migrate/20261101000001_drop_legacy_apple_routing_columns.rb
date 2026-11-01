# frozen_string_literal: true

class DropLegacyAppleRoutingColumns < ActiveRecord::Migration[7.2]
  def change
    remove_index :feeds, :apple_show_id, name: "index_feeds_on_apple_show_id"
    remove_column :feeds, :apple_show_id, :string

    remove_index :apple_configs, :key_id, name: "index_apple_configs_on_key_id"
    remove_column :apple_configs, :key_id, :bigint

    remove_index :apple_podcast_containers, :episode_id,
      unique: true,
      where: "apple_show_id IS NULL",
      name: "idx_apple_podcast_containers_legacy_episode_unique"
    remove_index :apple_podcast_containers, :apple_show_id,
      name: "index_apple_podcast_containers_on_apple_show_id"
    remove_index :integrations_episode_delivery_statuses, :apple_show_id,
      name: "index_integrations_episode_delivery_statuses_on_apple_show_id"
  end
end
