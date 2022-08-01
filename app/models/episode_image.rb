class EpisodeImage < ActiveRecord::Base
  belongs_to :episode, touch: true

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
    episode.with_lock do
      episode.images.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
