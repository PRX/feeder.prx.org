require "active_support/concern"

# Apple HLS delivery reads for an episode. The HLS media pipeline owns
# producing the master playlist; Apple delivery only reads it here.
module EpisodeAppleHls
  extend ActiveSupport::Concern

  included do
    has_many :apple_hls_alternate_assets, class_name: "Apple::HlsAlternateAsset", inverse_of: :episode
  end

  # Strict gate for staging this episode's HLS video with Apple: an HLS
  # video episode with a complete alternate (HLS) media resource.
  #
  # TODO: also check the master meets Apple's HLS requirements, once the
  # HLS transcode produces one.
  def hls_eligible_for_apple?
    video? && ready_alt_media.present?
  end

  # The feed-scoped HLS master playlist URL Apple should fetch.
  def apple_hls_master_url(feed:)
    enclosure_alt_url(feed: feed) if hls_eligible_for_apple?
  end
end
