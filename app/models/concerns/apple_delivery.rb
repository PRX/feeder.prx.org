require "active_support/concern"

module AppleDelivery
  extend ActiveSupport::Concern

  included do
    has_one :apple_sync_log, -> { episodes.apple }, foreign_key: :feeder_id, class_name: "SyncLog"
    has_one :apple_podcast_delivery, class_name: "Apple::PodcastDelivery"
    has_one :apple_podcast_container, class_name: "Apple::PodcastContainer"
    has_many :apple_podcast_deliveries, through: :apple_podcast_container, source: :podcast_deliveries,
      class_name: "Apple::PodcastDelivery"
    has_many :apple_podcast_delivery_files, through: :apple_podcast_deliveries, source: :podcast_delivery_files,
      class_name: "Apple::PodcastDeliveryFile"

    alias_method :podcast_container, :apple_podcast_container
    alias_method :apple_status, :apple_episode_delivery_status
  end

  def publish_to_apple?
    !!podcast.apple_config&.publish_to_apple?
  end

  def apple_update_delivery_status(attrs)
    update_episode_delivery_status(:apple, attrs)
  end

  def apple_episode_delivery_statuses
    episode_delivery_statuses.apple
  end

  def build_initial_delivery_status
    Integrations::EpisodeDeliveryStatus.default_status(:apple, self)
  end

  def apple_episode_delivery_status
    episode_delivery_status(:apple) || build_initial_delivery_status
  end

  def apple_needs_delivery?
    apple_episode_delivery_status.delivered == false
  end

  def apple_needs_upload?
    apple_episode_delivery_status.uploaded == false
  end

  def apple_mark_as_not_delivered!
    apple_episode_delivery_status.mark_as_not_delivered!
  end

  def apple_mark_as_delivered!
    apple_episode_delivery_status.mark_as_delivered!
  end

  def apple_mark_as_uploaded!
    apple_episode_delivery_status.mark_as_uploaded!
  end

  def apple_mark_as_not_uploaded!
    apple_episode_delivery_status.mark_as_not_uploaded!
  end

  def apple_prepare_for_delivery!
    # remove the previous delivery attempt (soft delete)
    apple_podcast_deliveries.map(&:destroy)
    apple_podcast_deliveries.reset
    apple_podcast_delivery_files.reset
    apple_podcast_container&.podcast_deliveries&.reset
  end

  def apple_mark_for_reupload!
    apple_mark_as_not_delivered!
  end

  def measure_asset_processing_duration
    Integrations::EpisodeDeliveryStatus.measure_asset_processing_duration(episode_delivery_statuses)
  end

  def apple_episode
    return nil if !persisted? || !publish_to_apple?

    if (show = podcast.apple_config&.build_publisher&.show)
      Apple::Episode.new(api: show.api, show: show, feeder_episode: self)
    end
  end
end
