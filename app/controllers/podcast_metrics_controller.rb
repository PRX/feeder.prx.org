class PodcastMetricsController < ApplicationController
  before_action :set_podcast

  def show
    authorize @podcast, :show?
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end
end
