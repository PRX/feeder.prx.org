# frozen_string_literal: true

# add an id to associate an apple_config to a single podcast
class AddPodcastIdToAppleConfigs < ActiveRecord::Migration[7.0]
  def up
    add_column :apple_configs, :podcast_id, :integer

    # for each apple_config, find the podcast from the public_feed, and set it
    ::Apple::Config.all.each do |config|
      next unless (pid = config.public_feed&.podcast_id)
      config.update!(podcast_id: pid)
      Rails.logger.info("Config updated", {apple_config: config.id, podcast: config.podcast_id, pid: pid})
    end
  end

  def down
    remove_column :apple_configs, :podcast_id
  end
end
