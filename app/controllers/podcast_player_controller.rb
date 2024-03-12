class PodcastPlayerController < ApplicationController
  def show
    @podcast = Podcast.find(params[:podcast_id])

    authorize @podcast, :show?

    @player_options = podcast_player_params
  end

  private

  def podcast_player_params
    nilify params
      .permit(:embed_player_type, :max_width, :embed_player_theme, :accent_color, :all_episodes, :episode_number, :season, :category)
      .with_defaults(EmbedPlayerHelper::DEFAULT_OPTIONS)
  end
end
