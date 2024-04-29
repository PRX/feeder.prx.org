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
    nilify params.fetch(:podcast, {}).permit(
      :donation_url,
      :payment_pointer
    )
  end
end
