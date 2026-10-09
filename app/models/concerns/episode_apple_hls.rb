require "active_support/concern"

module EpisodeAppleHls
  extend ActiveSupport::Concern

  HLS_FAILED_STATUSES = %w[error invalid].freeze
  HLS_PROCESSING_STATUSES = %w[started created processing retrying].freeze

  included do
    has_many :apple_hls_alternate_assets, class_name: "Apple::HlsAlternateAsset", inverse_of: :episode
  end

  def hls_eligible_for_apple?
    return false unless video? && uncut.present?

    hls = alternate_media_resource
    hls.present? && hls.status_complete? && hls.same_uncut?(uncut)
  end

  def hls_failed_for_apple?
    return false unless video? && uncut.present?
    return true if HLS_FAILED_STATUSES.include?(uncut.status)

    hls = alt_media
    hls.present? && hls.same_uncut?(uncut) && HLS_FAILED_STATUSES.include?(hls.status)
  end

  def hls_processing_for_apple?
    return false unless video? && uncut.present?
    return true if HLS_PROCESSING_STATUSES.include?(uncut.status)

    hls = alt_media
    hls.present? && hls.same_uncut?(uncut) && HLS_PROCESSING_STATUSES.include?(hls.status)
  end

  # Unprefixed and always uses the base dovetail HLS playlist enclosure, even
  # when an enclosure override (e.g.  Megaphone's MP3) replaces the enclosure.
  def apple_hls_master_url(feed:)
    enclosure_dovetail_url(feed: feed, prefix: false, ext: "m3u8") if hls_eligible_for_apple?
  end
end
