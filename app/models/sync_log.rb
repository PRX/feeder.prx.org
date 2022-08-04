# frozen_string_literal: true

class SyncLog < BaseModel
  self.inheritance_column = nil

  scope :complete, -> { where('sync_completed_at IS NOT NULL AND external_id IS NOT NULL') }

  enum feeder_type: {
    feeds: 'f',
    episodes: 'e'
  }

  def complete?
    sync_completed_at.present? && external_id.present?
  end
end
