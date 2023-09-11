class MediaVersionResource < ApplicationRecord
  belongs_to :media_version, touch: true
  belongs_to :media_resource

  has_one :episode, -> { with_deleted }, through: :media_version

  validate :media_resource_complete, on: :create

  def media_resource_complete
    unless media_resource&.status_complete?
      errors.add(:media_resource_id, :media_not_ready, message: "media not ready")
    end
  end
end
