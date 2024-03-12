class EpisodePlayerController < ApplicationController
  def show
    @episode = Episode.find_by_guid!(params[:episode_id])
    @podcast = @episode.podcast

    authorize @episode, :show?

    @player_options = episode_player_params
  end

  private

  def episode_player_params
    nilify params
      .permit(:embed_player_type, :max_width, :embed_player_theme, :accent_color)
      .with_defaults(EmbedPlayerHelper::DEFAULT_OPTIONS)
  end
end
