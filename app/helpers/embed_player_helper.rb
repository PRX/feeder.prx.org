module EmbedPlayerHelper
  include PrxAccess

  EMBED_PLAYER_PATH = "/e"
  EMBED_PLAYER_FEED = "uf"
  EMBED_PLAYER_GUID = "ge"
  EMBED_PLAYER_CARD = "ca"
  EMBED_PLAYER_TITLE = "tt"
  EMBED_PLAYER_SUBTITLE = "ts"
  EMBED_PLAYER_IMAGE = "ui"
  EMBED_PLAYER_RSS_URL = "us"
  EMBED_PLAYER_AUDIO_URL = "ua"
  DOVETAIL_TOKEN = "_t"
  EMBED_PLAYER_PLAYLIST = "sp"
  EMBED_PLAYER_SEASON = "se"
  EMBED_PLAYER_CATEGORY = "ct"

  def embed_player_episode_url(ep, type = nil, preview = false)
    params = {}

    if preview && !ep.published?
      params[EMBED_PLAYER_TITLE] = ep.title
      params[EMBED_PLAYER_SUBTITLE] = ep.podcast.title
      params[EMBED_PLAYER_IMAGE] = ep.ready_image&.url || ep.podcast.ready_image&.url
      params[EMBED_PLAYER_RSS_URL] = ep.podcast_feed_url
      params[EMBED_PLAYER_AUDIO_URL] = enclosure_with_token(ep)
    else
      params[EMBED_PLAYER_FEED] = ep.podcast_feed_url
      params[EMBED_PLAYER_GUID] = ep.item_guid
    end

    if type == "card" || type == "fixed_card"
      params[EMBED_PLAYER_CARD] = "1"
    end

    embed_params(params)
  end

  def embed_player_podcast_url(podcast, options, preview = false)
    params = {}

    params[EMBED_PLAYER_FEED] = podcast.published_url
    params[EMBED_PLAYER_PLAYLIST] = options[:episode_number] || "10"

    if params[EMBED_PLAYER_PLAYLIST].present?
      params[EMBED_PLAYER_SEASON] = options[:season]
      params[EMBED_PLAYER_CATEGORY] = options[:category]
    end

    embed_params(params)
  end

  def embed_player_episode_iframe(ep, type = nil, preview = false)
    src = embed_player_episode_url(ep, type, preview)
    allow = "monetization"

    if type == "card"
      # TODO: this is NOW working, but I'm not sure how helpful this is to a producer that wishes to embed it.
      tag.iframe src: src, allow: allow, width: "100%", height: "700", style: "--aspect-ratio: 2/3; width: 100%;"
    elsif type == "fixed_card"
      tag.iframe src: src, allow: allow, width: "500", height: "700"
    else
      tag.iframe src: src, allow: allow, width: "100%", height: "200"
    end
  end

  def embed_player_podcast_iframe(podcast, options, preview = false)
    src = embed_player_podcast_url(podcast, options, preview)
    allow = "monetization"

    if options[:embed_player_type] == "card"
      # TODO: this is NOW working, but I'm not sure how helpful this is to a producer that wishes to embed it.
      tag.iframe src: src, allow: allow, width: "100%", height: "700", style: "--aspect-ratio: 2/3; width: 100%;"
    elsif options[:embed_player_type] == "fixed_card"
      tag.iframe src: src, allow: allow, width: "500", height: "700"
    else
      tag.iframe src: src, allow: allow, width: "100%", height: "600", style: "--aspect-ratio: 2/3; width: 100%;"
    end
  end

  def embed_player_type_options(selected)
    opts = %w[standard card fixed_card].map { |v| [t("helpers.label.episode.embed_player_types.#{v}"), v] }
    options_for_select(opts, selected)
  end

  def embed_player_category_options(podcast, selected)
    opts = podcast.feed_episodes.pluck(:categories).flatten.uniq
    options_for_select(opts, selected)
  end

  private

  def embed_params(params)
    "#{play_root}#{EMBED_PLAYER_PATH}?#{params.to_query}"
  end

  def enclosure_with_token(ep)
    sep = ep.enclosure_url.include?("?") ? "&" : "?"
    ep.enclosure_url + sep + {DOVETAIL_TOKEN => prx_jwt}.to_query
  end
end
