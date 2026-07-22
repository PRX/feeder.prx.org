module Megaphone
  class EpisodeDeliveryStatus < Integrations::EpisodeDeliveryStatus
    def self.sti_name
      "megaphone"
    end

    def mark_as_uploaded!
      update_status(uploaded: true)
    end

    def mark_as_not_uploaded!
      update_status(uploaded: false)
    end

    # Whether the media file has been uploaded to Megaphone is a subset of
    # whether the episode has been delivered.
    def mark_as_delivered!
      update_status(delivered: true, uploaded: true, asset_processing_attempts: 0)
    end

    def mark_as_not_delivered!
      # source_media_version_id is intentionally omitted — it is preserved so
      # we can still compare the previously uploaded media version against the
      # current one.
      update_status(delivered: false, uploaded: false, asset_processing_attempts: 0)
    end

    private

    def update_status(attrs)
      self.class.update_status(integration, episode, attrs)
    end
  end
end
