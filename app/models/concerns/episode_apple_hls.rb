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
    hls_status_in?(HLS_FAILED_STATUSES)
  end

  def hls_processing_for_apple?
    hls_status_in?(HLS_PROCESSING_STATUSES)
  end

  # Unprefixed and always uses the base dovetail HLS playlist enclosure, even
  # when an enclosure override (e.g.  Megaphone's MP3) replaces the enclosure.
  def apple_hls_master_url(feed:)
    enclosure_dovetail_url(feed: feed, prefix: false, ext: "m3u8") if hls_eligible_for_apple?
  end

  private

  # The current upload, or its HLS transcode, has one of these statuses.
  def hls_status_in?(statuses)
    return false unless video? && uncut.present?
    return true if statuses.include?(uncut.status)

    hls = alternate_media_resource
    hls.present? && hls.same_uncut?(uncut) && statuses.include?(hls.status)
  end
end
