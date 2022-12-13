# frozen_string_literal: true

class SyncLog < ApplicationRecord
  self.inheritance_column = nil

  scope :complete, -> { where("sync_completed_at IS NOT NULL AND external_id IS NOT NULL") }

  enum feeder_type: {
    feeds: "feeds",
    episodes: "episodes",
    podcast_containers: "containers",
    podcast_deliveries: "deliveries",
    podcast_delivery_files: "delivery_files"
  }

  scope :latest, -> do
    joins("JOIN LATERAL ( SELECT max(id) as max_id
                          FROM sync_logs
                          GROUP BY feeder_type, feeder_id, external_id  ) q
                          ON id = max_id")
  end

  def complete?
    sync_completed_at.present? && external_id.present?
  end
end
