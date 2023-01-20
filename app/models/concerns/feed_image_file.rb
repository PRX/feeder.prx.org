require "active_support/concern"

module FeedImageFile
  extend ActiveSupport::Concern

  included do
    belongs_to :feed, touch: true, optional: true
    delegate :podcast, to: :feed, allow_nil: true
  end

  def destination_path
    "#{feed.podcast.path}/#{feed_image_path}"
  end

  def published_url
    "#{feed.podcast.base_published_url}/#{feed_image_path}"
  end

  def feed_image_path
    "images/#{guid}/#{file_name}"
  end
end
