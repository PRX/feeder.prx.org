class EpisodesController < ApplicationController
  def create
    @podcast = Podcast.find_by(podcast_params)
    @episode = Episode.with_deleted.find_or_initialize_by(prx_id: episode_params[:prx_id],
                                                          podcast_id: @podcast.id)

    @episode.overrides = episode_params[:overrides].to_json
    @episode.deleted_at = nil

    if @episode.save
      publish_feed
      render json: @episode
    else
      render json: @episode.errors
    end
  end

  def update
    @episode = Episode.find(params[:id])
    @podcast = @episode.podcast

    @episode.overrides = episode_params[:overrides].to_json

    if @episode.save
      publish_feed
      render nothing: true
    else
      render json: episode.errors
    end
  end

  def publish_feed
    return unless @podcast
    DateUpdater.both_dates(@podcast)
    PublishFeedJob.perform_later(@podcast)
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
