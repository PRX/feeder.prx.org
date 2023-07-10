module EmbedPlayerHelper
  include PrxAccess

  EMBED_PLAYER_PATH = "/e"
  EMBED_PLAYER_FEED = "uf"
  EMBED_PLAYER_GUID = "ge"
  EMBED_PLAYER_CARD = "ca"

  def embed_player_episode_url(ep, type = nil, preview = false)
    params = {}

    if preview && !episode.published?
      # TODO: private token auth url
      {}
    else
      params[EMBED_PLAYER_FEED] = ep.podcast_feed_url
      params[EMBED_PLAYER_GUID] = ep.item_guid
    end

    if type == "card" || type == "fixed_card"
      params[EMBED_PLAYER_CARD] = "1"
    end

    embed_params(params)
  end

  def embed_player_episode_iframe(ep, type = nil)
    if type == "card"
      # TODO: this is not working
      tag.div style: "width: 100%; height: calc(100% + 200px); position: relative;" do
        tag.iframe src: embed_player_episode_url(ep, type), style: "position: absolute; inset: 0;"
      end
    elsif type == "fixed_card"
      tag.iframe src: embed_player_episode_url(ep, type), width: "500", height: "700"
    else
      tag.iframe src: embed_player_episode_url(ep, type), width: "100%", height: "200"
    end
  end

  def embed_player_type_options(selected)
    opts = %w[standard card fixed_card].map { |v| [t("helpers.label.episode.embed_player_types.#{v}"), v] }
    options_for_select(opts, selected)
  end

  private

  def embed_params(params)
    "#{play_root}#{EMBED_PLAYER_PATH}?#{params.to_query}"
  end
end
