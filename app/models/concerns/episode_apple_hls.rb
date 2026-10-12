require "active_support/concern"

module EpisodeAppleHls
  extend ActiveSupport::Concern

  included do
    has_many :apple_hls_alternate_assets, class_name: "Apple::HlsAlternateAsset", inverse_of: :episode
  end

  def hls_eligible_for_apple?
    return false unless video? && uncut.present?

    hls = alt_media
    hls.present? && hls.status_complete? && hls.same_uncut?(uncut)
  end

  # Unprefixed and always uses the base dovetail HLS playlist enclosure, even
  # when an enclosure override (e.g.  Megaphone's MP3) replaces the enclosure.
  def apple_hls_master_url(feed:)
    enclosure_dovetail_url(feed: feed, prefix: false, ext: "m3u8") if hls_eligible_for_apple?
  end
end
