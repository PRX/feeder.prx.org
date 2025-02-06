class SubscribeLink < ApplicationRecord
  PLATFORMS = %w[apple spotify overcast pocketcasts youtube youtube_feed].freeze

  PLATFORM_HREFS = {
    "apple" => "https://podcasts.apple.com/podcast/id{external_id}",
    "spotify" => "https://open.spotify.com/{external_id}",
    "overcast" => "https://overcast.fm/itunes{external_id}",
    "pocketcasts" => "https://pca.st/itunes/{external_id}",
    "youtube" => "https://music.youtube.com/playlist?list={external_id}",
    "youtube_feed" => "https://music.youtube.com/library/podcasts?addrssfeed=${base64url(external_id}"
  }

  APPLE_PLATFORMS = %w[apple overcast pocketcasts]

  UNIQUE_PLATFORMS = %w[spotify youtube]

  FEED_PLATFORMS = %w[youtube_feed]

  belongs_to :podcast, -> { with_deleted }, optional: true, touch: true

  scope :with_apple_id, -> { where(platform: APPLE_PLATFORMS) }
  scope :with_platform_id, -> { where(platform: UNIQUE_PLATFORMS) }

  validates :platform, presence: true, inclusion: {in: PLATFORMS}
  validates :external_id, presence: true

  def uses_apple_id?
    APPLE_PLATFORMS.include?(platform)
  end

  def uses_unique_id?
    UNIQUE_PLATFORMS.include?(platform)
  end

  def uses_feed_url?
    FEED_PLATFORMS.include?(platform)
  end
end
