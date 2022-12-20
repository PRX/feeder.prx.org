# frozen_string_literal: true

class AddFieldsToPodcastContainer < ActiveRecord::Migration[7.0]
  def change
    add_column :apple_podcast_containers, :vendor_id, :string, blank: false, null: false
    add_column :apple_podcast_containers, :apple_episode_id, :string, blank: false, null: false
    add_column :apple_podcast_containers, :source_url, :string
    add_column :apple_podcast_containers, :source_filename, :string
    add_column :apple_podcast_containers, :source_size, :bigint
  end
end
