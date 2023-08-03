class PodcastPlayerController < ApplicationController
  before_action :set_podcast

  # GET /podcasts/1/player
  def show
    @player_options = {}
    @player_options[:embed_player_type] = params[:embed_player_type]
    @player_options[:episode_number] = params[:episode_number]
    @player_options[:season] = params[:season]
    @player_options[:category] = params[:category]
    @player_options[:recent] = params[:recent]
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end
end
