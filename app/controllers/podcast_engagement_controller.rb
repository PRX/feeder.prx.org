class PodcastEngagementController < ApplicationController
  before_action :set_podcast, only: %i[show edit update]
  before_action :set_podcast

  # GET /podcasts/1/engagement
  def show
  end

  # PATCH/PUT /podcasts/1/engagement
  def update
    respond_to do |format|
      if @podcast.update(podcast_engagement_params)
        format.html { redirect_to podcast_engagement_url(@podcast), notice: "Podcast engagement was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast
  end

  # Only allow a list of trusted parameters through.

  ### TODO include params for socmed and podcast apps
  def podcast_engagement_params
    params.fetch(:podcast, {}).permit(
      :title,
      :prx_account_uri,
      :donation_url,
      :payment_pointer
    )
  end
end
