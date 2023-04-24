class EpisodeImage < ActiveRecord::Base
  include ImageFile

  belongs_to :episode, touch: true, optional: true

  validates :height, :width, numericality: {greater_than_or_equal_to: 1400, less_than_or_equal_to: 3000}, if: :status_complete?
  validates :width, comparison: {equal_to: :height}, if: :status_complete?

  def destination_path
    "#{episode.path}/#{image_path}"
  end

  def published_url
    "#{episode.base_published_url}/#{image_path}"
  end

  def image_path
    "images/#{guid}/#{file_name}"
  end

  def replace_resources!
    EpisodeImage.where(episode_id: episode_id).where.not(id: id).touch_all(:replaced_at, :deleted_at)
  end
end
