class EpisodeSegmenterController < ApplicationController
  before_action :set_episode

  def show
    authorize @episode, :show?
    @uncut&.assign_attributes(uncut_params)
  end

  def update
    authorize @episode, :update?
    @uncut&.assign_attributes(uncut_params)

    respond_to do |format|
      if @uncut&.save
        @uncut.copy_media
        format.html { redirect_to episode_segmenter_url(@episode), notice: t(".notice") }
      else
        flash.now[:error] = t(".error")
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:episode_id])
    @podcast = @episode.podcast
    @uncut = @episode.uncut
  end

  def uncut_params
    params.fetch(:uncut, {}).permit(:segmentation).tap do |p|
      p[:segmentation] = parse_segmentation(p[:segmentation]) if p.key?(:segmentation)
    end
  end

  def parse_segmentation(str)
    if str.blank?
      nil
    else
      JSON.parse(str)
    end
  rescue JSON::ParserError
    str
  end
end
