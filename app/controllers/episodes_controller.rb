class EpisodesController < ApplicationController
  def create
    podcast = Podcast.find_by(podcast_params)
    @episode = Episode.new(prx_id: episode_params[:prx_id],
                           podcast_id: podcast.id,
                           overrides: episode_params[:overrides].to_json)

    if @episode.save
      render json: @episode
    else
      render json: @episode.errors
    end
  end

  private

  def episode_params
    id = params.require(:episode).permit(:prx_id)
    overrides = params[:episode].require(:overrides)
    id.merge(overrides: overrides)
  end

  def podcast_params
    params.require(:podcast).permit(:prx_id)
  end
end
