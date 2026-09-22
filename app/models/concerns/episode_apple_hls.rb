require "active_support/concern"

# Apple HLS delivery reads for an episode. The HLS media pipeline owns
# producing the master playlist; Apple delivery only reads it here.
module EpisodeAppleHls
  extend ActiveSupport::Concern

  included do
    has_many :apple_hls_alternate_assets, class_name: "Apple::HlsAlternateAsset", inverse_of: :episode
  end

  # Strict gate for staging this episode's HLS video with Apple.
  #
  # TODO: return true when the episode is a video episode whose canonical
  # media has a complete HLS master that meets Apple's HLS requirements.
  # The HLS media pipeline (AlternateMediaResource, feat/hls_video_media)
  # has not landed, so no episode is eligible yet.
  def hls_eligible_for_apple?
    false
  end

  # The HLS master playlist URL Apple should fetch for this feed.
  #
  # TODO: return the feed-scoped HLS master URL from the HLS media pipeline
  # (enclosure_alt_url(feed:) on feat/hls_video_media).
  def apple_hls_master_url(feed:)
    nil
  end
end
