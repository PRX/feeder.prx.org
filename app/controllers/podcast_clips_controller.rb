class PodcastClipsController < ApplicationController
  before_action :set_podcast
  before_action :set_clip, only: %i[show]

  def index
    @clips =
      @podcast.stream_resources
        .filter_by_alias(params[:filter])
        .filter_by_date(@stream_recording, params[:date])
        .sort_by_alias(params[:sort])
        .paginate(params[:page], params[:per])
        .includes(:stream_recording)
  end

  def show
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
    @stream_recording = @podcast.stream_recording
  end

  def set_clip
    @clip = @podcast.stream_resources.find(params[:id])
    authorize @clip
  end
end
