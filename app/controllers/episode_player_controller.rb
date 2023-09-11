class EpisodePlayerController < ApplicationController
  def show
    @episode = Episode.find_by_guid!(params[:episode_id])
    @podcast = @episode.podcast

    authorize @episode, :show?

    @player_options = {}
    @player_options[:embed_player_type] = params[:embed_player_type] || "standard"
    @player_options[:embed_player_theme] = params[:embed_player_theme] || "dark"
    @player_options[:accent_color] = params[:accent_color] || ['#ff9600']
    @player_options[:episode_guid] = Episode.find_by_guid!(params[:episode_id])
  end
end
