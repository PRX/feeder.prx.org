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
    fn = File.basename(URI.parse(original_url).path)
    "images/#{guid}/#{fn}"
  end

  def update_from_fixer(fixer_task)
    super(fixer_task)
    replace_resources!
  end

  def replace_resources!
    episode.with_lock do
      episode.images.where("created_at < ? AND id != ?", created_at, id).destroy_all
    end
  end
end
