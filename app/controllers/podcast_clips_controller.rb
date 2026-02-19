class PodcastClipsController < ApplicationController
  before_action :set_podcast
  before_action :set_clip, except: :index

  def index
    @clips =
      @podcast.stream_resources
        .filter_by_alias(params[:filter])
        .filter_by_date(@stream_recording, params[:date])
        .sort_by_alias(params[:sort])
        .paginate(params[:page], params[:per])
        .includes(stream_recording: :podcast)
  end

  def show
  end

  def attach
    if (ep = attach_to_episode(params[:stream_resource][:episode]))
      redirect_to episode_media_path(ep), notice: t(".attached")
    elsif (ep = create_new_episode(params[:stream_resource][:title], params[:stream_resource][:released_at]))
      redirect_to episode_media_path(ep), notice: t(".created")
    else
      redirect_to podcast_clips_path(@podcast), alert: t(".alert")
    end
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

  def attach_to_episode(guid = nil)
    ep = @podcast.episodes.find_by_guid(guid) if guid
    return unless ep

    uncut = @clip.copy_resource_to(ep.build_uncut)
    uncut.save!
    ep
  end

  def create_new_episode(title = nil, released_at = nil)
    ep = @podcast.episodes.build(title: title, released_at: released_at, medium: "uncut", segment_count: 1)
    return unless ep.save

    uncut = @clip.copy_resource_to(ep.build_uncut)
    uncut.save!
    ep
  end
end
