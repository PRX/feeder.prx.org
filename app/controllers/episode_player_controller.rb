class EpisodePlayerController < ApplicationController
  def show
    @episode = Episode.find_by_guid!(params[:episode_id])
    @podcast = @episode.podcast

    authorize @episode, :show?

    @embed_player_type = params[:embed_player_type]
  end
end
