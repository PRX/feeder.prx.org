class SubscribeLink < ApplicationRecord
  PLATFORMS = %w[apple spotify overcast pocketcasts youtube youtube_feed amazon antenna anytime apollo breez castamatic castbox castro curiocaster deezer fountain global goodpods gpodder hark iheart lnbeats luminary moon pandora player podbean podaddict podapp podguru_apple podguru_feed podrepublic podfriend podlp_apple podlp_guid podstation podurama podverse snipd sonnet steno truefans tunein].freeze

  PLATFORM_HREFS = {
    "apple" => "https://podcasts.apple.com/podcast/id${appleID}",
    "spotify" => "https://open.spotify.com/${uniquePlatformID}",
    "overcast" => "https://overcast.fm/itunes${appleID}",
    "pocketcasts" => "https://pca.st/itunes/${appleID}",
    "youtube" => "https://music.youtube.com/playlist?list=${uniquePlatformID}",
    "youtube_feed" => "https://music.youtube.com/library/podcasts?addrssfeed=${base64url$(feedURL}",
    "amazon" => "https://music.amazon.com/podcasts/${uniquePlatformID}",
    "antenna" => "https://antennapod.org/deeplink/subscribe?url=${feedURL}",
    "anytime" => "https://anytimeplayer.app/subscribe?url=${feedURL}",
    "apollo" => "https://shows.apollopods.com/show?feedUrl=${feedURL}",
    "breez" => "https://breez.link/p?feedURL=${encodeURIComponent(feedURL)}",
    "castamatic" => "https://castamatic.com/guid/${podcastGUID}",
    "castbox" => "https://castbox.fm/vic/${appleID}",
    "castro" => "https://castro.fm/itunes/${appleID}",
    "curiocaster" => "https://curiocaster.com/podcast/pi${podcastIndexShowID}",
    "deezer" => "https://www.deezer.com/show/${uniquePlatformID}",
    "fountain" => "https://fountain.fm/show/${podcastIndexShowID}",
    "global" => "https://www.globalplayer.com/podcasts/${uniquePlatformID}",
    "goodpods" => "https://www.goodpods.com/podcasts-aid/${appleID}",
    "gPodder" => "https://gpodder.net/subscribe?url=${feedURL}",
    "hark" => "https://harkaudio.com/p/${uniquePlatformID}",
    "iheart" => "https://iheart.com/podcast/${uniquePlatformID}",
    "lnbeats" => "https://lnbeats.com/album/${podcastGUID}",
    "luminary" => "https://luminarypodcasts.com/listen/${slug}/${slug}/${uniquePlatformID}",
    "moon" => "https://moon.fm/itunes/${appleID}",
    "pandora" => "https://pandora.com/podcast/${slug}/PC:${uniquePlatformID}",
    "player" => "https://player.fm/subscribe?id=${encodeURIComponent(feedURL)}",
    "podbean" => "https://www.podbean.com/itunes/${appleID}",
    "podaddict" => "https://podcastaddict.com/feed/${encodeURIComponent(feedURL)}",
    "podapp" => "https://podcast.app/${slug}-p${uniquePlatformID}",
    "podguru_apple" => "https://app.podcastguru.io/podcast/${appleID}",
    "podguru_feed" => "https://app.podcastguru.io/podcast/X${hex(feedURL)}",
    "podrepublic" => "https://www.podcastrepublic.net/podcast/${appleID}",
    "podfriend" => "https://podfriend.com/podcast/${appleID}",
    "podlp_apple" => "https://link.podlp.app/${appleID}",
    "podlp_guid" => "https://link.podlp.app/${podcastGUID}",
    "podstation" => "https://podstation.github.io/subscribe-ext/?feedURL=${feedURL}",
    "podurama" => "https://podurama.com/podcast/${slug}-i${appleID}",
    "podverse" => "https://api.podverse.fm/api/v1/podcast/podcastindex/${podcastIndexShowID}",
    "snipd" => "https://share.snipd.com/show/${uniquePlatformID}",
    "sonnet" => "https://sonnet.fm/p/${appleID}",
    "steno" => "https://steno.fm/show/${podcastGUID}",
    "truefans" => "https://truefans.fm/${podcastGUID}",
    "tunein" => "https://tunein.com/podcasts/${uniquePlatformID}"
  }

  PLATFORM_ICONS = {
    "apple" => "apple",
    "spotify" => "spotify",
    "overcast" => "overcast",
    "pocketcasts" => "pocketcasts",
    "youtube" => "youtube",
    "youtube_feed" => "youtube",
    "amazon" => "amazon",
    "antenna" => "antenna",
    "anytime" => "anytime",
    "apollo" => "apollo",
    "breez" => "breez",
    "castamatic" => "castamatic",
    "castbox" => "castbox",
    "castro" => "castro",
    "curiocaster" => "curiocaster",
    "deezer" => "deezer",
    "fountain" => "fountain",
    "global" => "global",
    "goodpods" => "goodpods",
    "gpodder" => "gpodder",
    "hark" => "hark",
    "iheart" => "iheart",
    "lnbeats" => "lnbeats",
    "luminary" => "luminary",
    "moon" => "moon",
    "pandora" => "pandora",
    "player" => "player",
    "podbean" => "podbean",
    "podaddict" => "podaddict",
    "podapp" => "podapp",
    "podguru_apple" => "podguru",
    "podguru_feed" => "podguru",
    "podrepublic" => "podrepublic",
    "podfriend" => "podfriend",
    "podlp_apple" => "podlp",
    "podlp_guid" => "podlp",
    "podstation" => "podstation",
    "podurama" => "podurama",
    "podverse" => "podverse",
    "snipd" => "snipd",
    "sonnet" => "sonnet",
    "steno" => "steno",
    "truefans" => "truefans",
    "tunein" => "tunein"
  }

  COMMON_PLATFORMS = %w[apple spotify overcast pocketcasts youtube youtube_feed]

  APPLE_PLATFORMS = %w[apple overcast pocketcasts castbox castro goodpods moon podbean podguru_apple podrepublic podfriend podlp_apple podurama sonnet]

  UNIQUE_PLATFORMS = %w[spotify youtube amazon deezer global hark iheart luminary pandora podapp snipd tunein]

  FEED_PLATFORMS = %w[youtube_feed antenna anytime apollo breez gpodder player podaddict podguru_feed podstation]

  GUID_PLATFORMS = %w[castamatic lnbeats podlp_guid steno truefans]

  POD_INDEX_PLATFORMS = %w[curiocaster fountain podverse]

  SLUG_PLATFORMS = %w[luminary podapp]

  belongs_to :podcast, -> { with_deleted }, optional: true, touch: true

  scope :with_apple_id, -> { where(platform: APPLE_PLATFORMS) }

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

  def uses_podcast_guid?
    GUID_PLATFORMS.include?(platform)
  end

  def uses_pod_index_id?
    POD_INDEX_PLATFORMS.include?(platform)
  end

  def icon
    PLATFORM_ICONS[platform]
  end
end
