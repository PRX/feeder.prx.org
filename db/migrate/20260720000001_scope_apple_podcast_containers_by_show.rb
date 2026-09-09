# frozen_string_literal: true

class ScopeApplePodcastContainersByShow < ActiveRecord::Migration[7.2]
  def up
    add_index :apple_podcast_containers,
      [:episode_id, :apple_show_id],
      unique: true,
      name: "idx_apple_podcast_containers_episode_show_unique"
    add_index :apple_podcast_containers,
      :episode_id,
      unique: true,
      where: "apple_show_id IS NULL",
      name: "idx_apple_podcast_containers_legacy_episode_unique"

    remove_index :apple_podcast_containers,
      name: "index_apple_podcast_containers_on_episode_id"
  end

  def down
    add_index :apple_podcast_containers,
      :episode_id,
      unique: true,
      name: "index_apple_podcast_containers_on_episode_id"

    remove_index :apple_podcast_containers,
      name: "idx_apple_podcast_containers_episode_show_unique"
    remove_index :apple_podcast_containers,
      name: "idx_apple_podcast_containers_legacy_episode_unique"
  end
end
