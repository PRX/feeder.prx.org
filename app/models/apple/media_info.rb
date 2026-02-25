# frozen_string_literal: true

module Apple
  MediaInfo = Struct.new(:episode, :source_media_version_id, :source_size, :source_url, keyword_init: true) do
    def has_media_version?
      source_media_version_id.present? &&
        source_media_version_id == episode.feeder_episode.media_version_id
    end

    def source_attributes
      {source_media_version_id: source_media_version_id, source_size: source_size, source_url: source_url}
    end

    # Build from persisted delivery status (for skip-upload fast path)
    def self.from_delivery_status(apple_episode)
      status = apple_episode.delivery_status
      new(
        episode: apple_episode,
        source_media_version_id: status&.source_media_version_id,
        source_size: status&.source_size,
        source_url: status&.source_url
      )
    end

    # Fast path guard: media version matches AND all source attrs present
    def self.complete_from_delivery_status?(apple_episode)
      mi = from_delivery_status(apple_episode)
      mi.has_media_version? && mi.source_size.present? && mi.source_url.present?
    end
  end
end
