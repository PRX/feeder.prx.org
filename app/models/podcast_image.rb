class PodcastImage < ActiveRecord::Base
  belongs_to :podcast, touch: true

  include ImageFile

  def destination_path
    "#{podcast.path}/#{podcast_image_path}"
  end

  def published_url
    "#{podcast.base_published_url}/#{podcast_image_path}"
  end

  def podcast_image_path
    fn = File.basename(URI.parse(original_url).path)
    "images/#{guid}/#{fn}"
  end
end
