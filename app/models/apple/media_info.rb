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
  end
end
