class PodcastEngagementController < ApplicationController
  before_action :set_podcast

  def show
  end

  # PATCH/PUT /podcasts/1/engagement
  def update
    @podcast.assign_attributes(podcast_engagement_params)

    respond_to do |format|
      if @podcast.save
        @podcast.publish!
        format.html { redirect_to podcast_engagement_path(@podcast), notice: t(".notice") }
      else
        flash.now[:error] = t(".error")
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  rescue ActiveRecord::StaleObjectError
    render :show, status: :conflict
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    @podcast.locking_enabled = true
    authorize @podcast
  end

  # Only allow a list of trusted parameters through.

  ### TODO include params for socmed and podcast apps
  def podcast_engagement_params
    nilify params.fetch(:podcast, {}).permit(
      :lock_version,
      :donation_url,
      :payment_pointer,
      subscribe_links_attributes: %i[id enabled external_id platform]
    )
  end
end
