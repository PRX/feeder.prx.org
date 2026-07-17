class RemovePollutedAppleEpisodeDeliveryStatuses < ActiveRecord::Migration[7.2]
  def up
    configured_podcast_ids = Feed.with_deleted
      .where(id: Apple::Config.select(:feed_id))
      .where.not(podcast_id: nil)
      .select(:podcast_id)

    configured_episode_ids = Episode.with_deleted.where(podcast_id: configured_podcast_ids).select(:id)
    apple_sync_episode_ids = SyncLog.apple.episodes.where.not(feeder_id: nil).select(:feeder_id)
    apple_container_episode_ids = Apple::PodcastContainer.where.not(episode_id: nil).select(:episode_id)

    polluted_statuses = Integrations::EpisodeDeliveryStatus.apple
      .joins(:episode)
      .where(
        apple_show_id: nil,
        delivered: [false, nil],
        uploaded: [false, nil],
        source_url: [nil, ""],
        source_filename: [nil, ""],
        source_size: nil,
        enclosure_url: [nil, ""],
        source_fetch_count: [nil, 0],
        source_media_version_id: nil,
        asset_processing_attempts: [nil, 0]
      )
      .where.not(episode_id: configured_episode_ids)
      .where.not(episode_id: apple_sync_episode_ids)
      .where.not(episode_id: apple_container_episode_ids)

    polluted_statuses.delete_all

    practicecast = Podcast.find_by(id: 5472)
    Integrations::EpisodeDeliveryStatus.where(episode: practicecast.episodes).delete_all if practicecast
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Deleted polluted Apple delivery statuses cannot be restored"
  end
end
