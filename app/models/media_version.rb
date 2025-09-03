class MediaVersion < ApplicationRecord
  belongs_to :episode, -> { with_deleted }, touch: true, optional: true

  has_many :media_version_resources, dependent: :destroy
  has_many :media_resources, -> { with_deleted.order("position ASC, created_at DESC") }, through: :media_version_resources

  scope :latest, ->(episode_ids = nil) do
    if episode_ids.present?
      where("id IN (SELECT MAX(id) FROM media_versions WHERE episode_id IN (?) GROUP BY episode_id)", episode_ids)
    else
      where("id IN (SELECT MAX(id) FROM media_versions GROUP BY episode_id)")
    end
  end

  validates :media_version_resources, length: {minimum: 1}
end
