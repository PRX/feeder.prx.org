class EpisodePlayerController < ApplicationController
  def show
    @episode = Episode.find_by_guid!(params[:episode_id])
    @podcast = @episode.podcast
  end
end
