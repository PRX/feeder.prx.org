class PodcastPlayerController < ApplicationController
  before_action :set_podcast

  def show
    authorize @podcast, :show?

    @player_options = podcast_player_params
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def podcast_player_params
    nilify params
      .permit(:embed_player_type, :max_width, :embed_player_theme, :accent_color, :all_episodes, :episode_number, :season, :category)
      .with_defaults(EmbedPlayerHelper::DEFAULT_OPTIONS)
  end
end
