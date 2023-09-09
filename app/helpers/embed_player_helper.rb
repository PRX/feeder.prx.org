module EmbedPlayerHelper
  include PrxAccess

  EMBED_PLAYER_LANDING_PATH = "/listen"
  EMBED_PLAYER_PATH = "/e"
  EMBED_PLAYER_PREVIEW_PATH = "/preview"
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

  def embed_player_landing_url(podcast, ep = nil)
    params = {}
    params[EMBED_PLAYER_FEED] = podcast&.public_url
    params[EMBED_PLAYER_GUID] = ep.item_guid if ep.present?
    "#{play_root}#{EMBED_PLAYER_LANDING_PATH}?#{params.to_query}"
  end

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

    if options[:all_episodes] === "all"
      params[EMBED_PLAYER_PLAYLIST] = "all"
    end

    if options[:all_episodes] == "number" && options[:episode_number].to_i > 1
      params[EMBED_PLAYER_PLAYLIST] = options[:episode_number]
    end

    if !options[:season].to_s.strip.empty? && options[:season].to_i > 0
      params[EMBED_PLAYER_SEASON] = options[:season]
    end

    if !options[:category].to_s.strip.empty?
      params[EMBED_PLAYER_CATEGORY] = options[:category]
    end

    if options[:embed_player_type] == "card" || options[:embed_player_type] == "fixed_card"
      params[EMBED_PLAYER_CARD] = "1"
    end

    embed_params(params)
  end

  def embed_player_episode_iframe(ep, type = nil, preview = false)
    src = embed_player_episode_url(ep, type, preview)
    allow = "monetization origin"
    data = { :embed_preview_target => 'embedIframe' }

    if type == "card"
      # Responsive cards require a wrapper div around iframe. The wrapper uses padding to determine the size of the area the iframe should fill.
      tag.div style: "position: relative; height: 0; width: 100%; padding-top: calc(100% + 200px);" do
        tag.iframe src: src, allow: allow, width: "100%", height: "100%", style: "position: absolute; inset: 0;", data: data
      end
    elsif type == "fixed_card"
      # Fixxed card heights should always be 200px larger than the width.
      tag.iframe src: src, allow: allow, width: "500", height: "700", data: data
    else
      tag.iframe src: src, allow: allow, width: "100%", height: "200", data: data
    end
  end

  def embed_player_iframe(options)
    src = ''
    allow = "monetization"
    iframeHeight = '200'
    iframeStyle = ''
    wrapperStyle = 'line-height: 0;'

    if options[:embed_player_type] == "card"
      wrapperStyle = "position: relative; height: 0; width: 100%; padding-top: calc(100% + #{iframeHeight}px); line-height: 0;"
      iframeHeight = '100%'
      iframeStyle = "position: absolute; inset: 0;"
    end


    tag.div style: wrapperStyle, data: { :embed_preview_target => 'embedIframeWrapper' } do
      tag.iframe class: 'bg-light', src: src, allow: allow, width: "100%", height: iframeHeight, style: iframeStyle, data: { :embed_preview_target => 'embedIframe' }
    end
  end

  def embed_player_type_options(selected)
    opts = %w[standard card].map { |v| [t("helpers.label.episode.embed_player_types.#{v}"), v] }
    options_for_select(opts, selected)
  end

  def embed_player_theme_options(selected)
    opts = %w[dark light auto].map { |v| [t("helpers.label.episode.embed_player_themes.#{v}"), v] }
    options_for_select(opts, selected)
  end

  def embed_player_category_options(podcast, selected)
    opts = podcast.feed_episodes.pluck(:categories).flatten.uniq
    options_for_select(opts, selected)
  end

  def embed_player_all_episodes_options(selected)
    opts = %w[all number].map { |v| [t("helpers.label.podcast_player.episodes_options.#{v}"), v] }
    options_for_select(opts, selected)
  end

  private

  def embed_params(params)
    "https://#{ENV["PLAY_HOST"]}#{EMBED_PLAYER_PREVIEW_PATH}?#{params.to_query}"
  end

  def enclosure_with_token(ep)
    sep = ep.enclosure_url.include?("?") ? "&" : "?"
    ep.enclosure_url + sep + {DOVETAIL_TOKEN => prx_jwt}.to_query
  end
end
