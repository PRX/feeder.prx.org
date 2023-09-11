class MediaVersion < ApplicationRecord
  belongs_to :episode, -> { with_deleted }, touch: true, optional: true

  has_many :media_version_resources, dependent: :destroy
  has_many :media_resources, -> { with_deleted.order("position ASC, created_at DESC") }, through: :media_version_resources

  validates :media_version_resources, length: {minimum: 1}
end
