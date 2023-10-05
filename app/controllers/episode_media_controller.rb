class EpisodeMediaController < ApplicationController
  before_action :set_episode

  # GET /episodes/1/media
  def show
    authorize @episode, :show?
    @episode.assign_attributes(parsed_episode_params)
    @episode.valid?
  end

  # GET /episodes/1/media/status
  def status
    authorize @episode, :show?
    render :status, layout: false
  end

  # PATCH/PUT /episodes/1/media
  def update
    authorize @episode, :update?
    @episode.assign_attributes(parsed_episode_params)

    respond_to do |format|
      if @episode.save
        @episode.uncut&.slice_contents!
        @episode.copy_media
        format.html { redirect_to episode_media_path(@episode), notice: t(".notice") }
      elsif @episode.errors.added?(:base, :media_not_ready)
        @episode.build_contents.each(&:valid?)
        flash.now[:error] = t(".media_not_ready")
        format.html { render :show, status: :unprocessable_entity }
      else
        flash.now[:error] = t(".error")
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:episode_id])
    @episode.strict_validations = true
    @podcast = @episode.podcast
  end

  def episode_params
    nilify params.fetch(:episode, {}).permit(
      :medium,
      :ad_breaks,
      contents_attributes: %i[id position original_url file_size _destroy _retry],
      uncut_attributes: %i[id segmentation original_url file_size _destroy _retry]
    )
  end

  # NOTE: the uncut "segmentation" field is json encoded
  def parsed_episode_params
    episode_params.tap do |p|
      if p[:uncut_attributes].present?
        p[:uncut_attributes][:segmentation] = parse_segmentation(p[:uncut_attributes][:segmentation])
      end
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
