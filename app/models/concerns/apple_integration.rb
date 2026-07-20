require "active_support/concern"

module AppleIntegration
  extend ActiveSupport::Concern

  included do
    has_one :apple_sync_log, -> { episodes.apple }, foreign_key: :feeder_id, class_name: "Apple::SyncLog"
    has_many :apple_podcast_containers, class_name: "Apple::PodcastContainer"

    private :apple_sync_log,
      :apple_sync_log=,
      :build_apple_sync_log,
      :create_apple_sync_log,
      :create_apple_sync_log!,
      :reload_apple_sync_log,
      :reset_apple_sync_log,
      :apple_podcast_containers,
      :apple_podcast_containers=,
      :apple_podcast_container_ids,
      :apple_podcast_container_ids=
  end

  def publish_to_apple?
    !!podcast.apple_config&.publish_to_apple?
  end

  def apple_episode
    return nil if !persisted? || !publish_to_apple?

    if (show = podcast.apple_config&.build_publisher&.show)
      return nil unless show.apple_id.present?

      Apple::Episode.new(api: show.api, show: show, feeder_episode: self)
    end
  end
end
