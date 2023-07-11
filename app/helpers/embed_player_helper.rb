module EmbedPlayerHelper
  include PrxAccess

  EMBED_PLAYER_PATH = "/e"
  EMBED_PLAYER_FEED = "uf"
  EMBED_PLAYER_GUID = "ge"

  def embed_player_episode_url(ep, preview = false)
    if preview && !episode.published?
      # TODO: private token auth url
    else
      embed_params(EMBED_PLAYER_FEED => ep.podcast_feed_url, EMBED_PLAYER_GUID => ep.item_guid)
    end
  end

  private

  def embed_params(params)
    "#{play_root}#{EMBED_PLAYER_PATH}?#{params.to_query}"
  end
end
