require "active_support/concern"

# Apple HLS delivery reads for an episode. The HLS media pipeline owns
# producing the master playlist; Apple delivery only reads it here.
module EpisodeAppleHls
  extend ActiveSupport::Concern

  included do
    has_many :apple_hls_alternate_assets, class_name: "Apple::HlsAlternateAsset", inverse_of: :episode
  end

  # Strict gate for staging this episode's HLS video with Apple: an HLS
  # video episode whose current upload has a complete HLS transcode. Unlike
  # ready_alt_media (which RSS uses to keep serving the last complete
  # playlist), a replacement upload that is still processing or failed is
  # not eligible, so Apple keeps whatever it already has.
  #
  # TODO: also check the master meets Apple's HLS requirements, once the
  # HLS transcode produces one.
  def hls_eligible_for_apple?
    return false unless video? && uncut.present?

    hls = alt_media
    hls.present? && hls.status_complete? && hls.same_uncut?(uncut)
  end

  # The feed-scoped HLS master playlist URL Apple should fetch. Unprefixed,
  # like Apple::Episode#enclosure_url, so a feed's enclosure prefix (and any
  # change to it) never reaches Apple.
  def apple_hls_master_url(feed:)
    enclosure_alt_url(feed: feed, prefix: false) if hls_eligible_for_apple?
  end
end
