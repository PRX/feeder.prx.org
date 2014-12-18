class PodcastsController < ApplicationController
  def show
    @podcast = Podcast.find(podcast_params)
    @categories = @podcast.itunes_categories
    @episodes = @podcast.episodes.order('created_at desc')
  end

  private

  def podcast_params
    params.permit(:id).require(:id)
  end
end
