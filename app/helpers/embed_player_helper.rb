module EmbedPlayerHelper
  include Prx::Api
  include ActionView::Helpers::TagHelper

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
  EMBED_PLAYER_AUDIO_URL_PREVIEW = "uap"
  DOVETAIL_TOKEN = "_t"
  EMBED_PLAYER_PLAYLIST = "sp"
  EMBED_PLAYER_SEASON = "se"
  EMBED_PLAYER_CATEGORY = "ct"
  EMBED_PLAYER_THEME = "th"
  EMBED_PLAYER_ACCENT_COLOR = "ac"

  DEFAULT_OPTIONS = {
    embed_player_type: "standard",
    embed_player_theme: "dark",
    accent_color: "#ff9600"
  }

  HEIGHT_BASE = 200
  HEIGHT_PLAYLIST_HEADER = 57
  HEIGHT_PLAYLIST_ROW = 61

  def embed_url?(value)
    value.blank? || value.include?(ENV["PLAY_HOST"])
  end

  def embed_episode_maybe_not_in_feed?(ep)
    !(ep.published? && ep.published_at <= 15.minutes.ago)
  end

  def embed_player_landing_url(podcast, ep = nil)
    params = {}
    params[EMBED_PLAYER_FEED] = podcast&.public_url
    params[EMBED_PLAYER_GUID] = ep.item_guid if ep.present?
    "#{play_root}#{EMBED_PLAYER_LANDING_PATH}?#{params.to_query}"
  end

  def embed_player_episode_url(ep, options = {}, preview = false)
    params = embed_params(options)

    if preview && embed_episode_maybe_not_in_feed?(ep)
      params[EMBED_PLAYER_TITLE] = ep.title
      params[EMBED_PLAYER_SUBTITLE] = ep.podcast.title
      params[EMBED_PLAYER_IMAGE] = ep.ready_image&.url || ep.podcast.ready_image&.url
      params[EMBED_PLAYER_RSS_URL] = ep.podcast_feed_url
      params[EMBED_PLAYER_AUDIO_URL] = ep.enclosure_url
      params[EMBED_PLAYER_AUDIO_URL_PREVIEW] = enclosure_with_token(ep)
    else
      params[EMBED_PLAYER_FEED] = ep.podcast_feed_url
      params[EMBED_PLAYER_GUID] = ep.item_guid
    end

    embed_url(params, preview)
  end

  def embed_player_episode_iframe(episode, options = {}, preview = false)
    embed_player_iframe(options, embed_player_episode_url(episode, options, preview))
  end

  def embed_player_podcast_url(podcast, options = {}, preview = false)
    params = embed_params(options.merge(playlist: true))
    params[EMBED_PLAYER_FEED] = podcast.public_url
    embed_url(params, preview)
  end

  def embed_player_podcast_iframe(podcast, options = {}, preview = false)
    embed_player_iframe(options.merge(playlist: true), embed_player_podcast_url(podcast, options, preview))
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
    opts = podcast.episodes.published.pluck(:categories).flatten.uniq
    options_for_select(opts, selected)
  end

  def enclosure_with_token(ep)
    url = EnclosureUrlBuilder.new.base_enclosure_url(ep.podcast, ep, ep.podcast.default_feed)
    sep = url.include?("?") ? "&" : "?"
    url + sep + {DOVETAIL_TOKEN => prx_jwt}.to_query
  end

  private

  def embed_params(options_with_defaults = {})
    opts = options_with_defaults.reject do |key, val|
      DEFAULT_OPTIONS[key.to_sym] == val
    end

    # shared params
    params = {}
    params[EMBED_PLAYER_CARD] = "1" if opts[:embed_player_type] == "card"
    params[EMBED_PLAYER_THEME] = opts[:embed_player_theme] if opts[:embed_player_theme].present?
    params[EMBED_PLAYER_ACCENT_COLOR] = opts[:accent_color].sub("#", "") if opts[:accent_color].present?

    # playlist params
    if opts[:playlist]
      params[EMBED_PLAYER_PLAYLIST] = (opts[:episode_number].to_i > 1) ? opts[:episode_number] : "all"
      params[EMBED_PLAYER_SEASON] = opts[:season] if opts[:season].to_i > 0
      params[EMBED_PLAYER_CATEGORY] = opts[:category] if opts[:category].to_s.strip.present?
    end

    params
  end

  def embed_url(params, preview = false)
    "https://#{ENV["PLAY_HOST"]}#{preview ? EMBED_PLAYER_PREVIEW_PATH : EMBED_PLAYER_PATH}?#{params.to_query}"
  end

  def embed_player_iframe(options, src = "")
    is_card = options[:embed_player_type] == "card"
    fixed_width = options[:max_width].to_i if options[:max_width].to_i >= 300

    # calculate height for playlists
    height =
      if options[:episode_number].to_i.between?(1, 5)
        HEIGHT_BASE + HEIGHT_PLAYLIST_HEADER + HEIGHT_PLAYLIST_ROW * options[:episode_number].to_i
      elsif options[:playlist]
        (HEIGHT_BASE + HEIGHT_PLAYLIST_HEADER + HEIGHT_PLAYLIST_ROW * 5.5).round
      else
        HEIGHT_BASE
      end

    # defaults
    iframe_opts = {
      allow: "monetization",
      frameborder: "0",
      height: height,
      width: "100%",
      style: fixed_width ? "min-width: #{fixed_width}px; max-width: #{fixed_width}px; display: block; margin-inline: auto" : "min-width: 300px",
      src: src
    }

    iframe_opts[:scrolling] = "no" unless options[:playlist]
    wrapper_style = "position: relative; height: 0; width: 100%; min-width: 300px;"

    # card styling
    if is_card
      iframe_opts[:height] = "100%"
      iframe_opts[:style] = "position: absolute; inset: 0;"
      wrapper_style << if fixed_width
        " padding-top: clamp(#{300 + height}px, calc(100% + #{height}px), #{fixed_width + height}px); margin-inline: auto; max-width: #{fixed_width}px;"
      else
        " padding-top: calc(100% + #{height}px);"
      end
    end

    # only cards get the wrapper div
    if is_card
      tag.div style: wrapper_style do
        tag.iframe(**iframe_opts)
      end
    else
      tag.iframe(**iframe_opts)
    end
  end
end
