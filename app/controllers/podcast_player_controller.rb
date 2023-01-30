class PodcastPlayerController < ApplicationController
  before_action :set_podcast

  # GET /podcasts/1/player
  def show
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end
end
