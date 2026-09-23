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

  # TEMP: inert copies of the HLS media interface from feat/hls_video_media,
  # so the gate above can be written against it. Delete these when this
  # branch is rebased onto that work. EpisodeMedia and EpisodeEnclosure are
  # included after this concern, so their real definitions take precedence.

  # TEMP: EpisodeMedia#video? on feat/hls_video_media (medium_video?, where
  # the new "video" medium is an HLS-transcoded Uncut). No medium here means
  # that yet; this branch's medium_video? is that branch's medium_passthru?.
  def video?
    false
  end

  # TEMP: EpisodeMedia#ready_alt_media on feat/hls_video_media
  # (complete_alternate_media_resource if video?).
  def ready_alt_media
    nil
  end

  # TEMP: EpisodeEnclosure#enclosure_alt_url on feat/hls_video_media
  # (enclosure_url(**opts, ext: "m3u8") if video?).
  def enclosure_alt_url(**opts)
    nil
  end

  # TEMP: EpisodeEnclosure#enclosure_alt_content_type on feat/hls_video_media.
  def enclosure_alt_content_type
    "application/x-mpegURL" if video?
  end
end
