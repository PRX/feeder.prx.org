class EpisodePlayerController < ApplicationController
  before_action :set_episode

  def show
    authorize @episode, :show?

    @player_options = episode_player_params
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:episode_id])
    @podcast = @episode.podcast
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def episode_player_params
    nilify params
      .permit(:embed_player_type, :max_width, :embed_player_theme, :accent_color)
      .with_defaults(EmbedPlayerHelper::DEFAULT_OPTIONS)
  end
end
