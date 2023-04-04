class EpisodeImage < ActiveRecord::Base
  belongs_to :episode, touch: true, optional: true

  include ImageFile

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
