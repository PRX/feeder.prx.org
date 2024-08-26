class EpisodeTranscriptsController < ApplicationController
  before_action :set_episode

  # GET /episodes/1/transcripts
  def show
    authorize @episode, :show?

    @episode.assign_attributes(episode_params)
    @episode.valid?
  end

  # GET /episodes/1/transcripts/status
  def status
    authorize @episode, :show?
    render :status, layout: false
  end

  # PATCH/PUT /episodes/1/transcripts
  def update
    authorize @episode, :update?
    @episode.assign_attributes(episode_params)

    respond_to do |format|
      if @episode.save
        @episode.copy_media
        format.html { redirect_to episode_transcripts_path(@episode), notice: t(".notice") }
      elsif @episode.errors.added?(:base, :media_not_ready)

        # some UI feedback that these files aren't ready
        # if @episode.medium_uncut?
        #   (@episode.uncut || @episode.build_uncut).valid?
        # else
        #   @episode.build_contents.each(&:valid?)
        # end

        flash.now[:error] = t(".media_not_ready")
        format.html { render :show, status: :unprocessable_entity }
      else
        flash.now[:error] = t(".error")
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::StaleObjectError
    render :show, status: :conflict
  end

  private

  def set_episode
    @episode = Episode.find_by_guid!(params[:episode_id])
    @episode.strict_validations = true
    @episode.locking_enabled = true
    @podcast = @episode.podcast
  end

  def episode_params
    nilify params.fetch(:episode, {}).permit(
      :lock_version,
      transcript_attributes: %i[id original_url file_size _destroy _retry]
    )
  end
end
