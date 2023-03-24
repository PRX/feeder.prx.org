class PodcastPlannerController < ApplicationController
  before_action :set_podcast

  # GET /podcasts/1/planner
  def show
    @planner = PodcastPlanner.new(planner_params)
    @planner.generate_dates!
  end

  # PATCH/PUT /podcasts/1/planner
  def update
    @planner = PodcastPlanner.new(planner_params)
    @planner.generate_dates!
    @planner.generate_drafts!

    respond_to do |format|
      if Episode.insert_all(@planner.drafts)
        format.html { redirect_to podcast_episodes_path(@podcast), notice: t(".success") }
      else
        format.html { render :show, status: :unprocessable_entity }
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  # Only allow a list of trusted parameters through.
  def planner_params
    params.permit(
      :podcast_id,
      :week_condition,
      :period,
      :start_date,
      :date_range_condition,
      :number_of_episodes,
      :end_date,
      :publish_time,
      :segment_count,
      selected_days: [],
      monthly_weeks: []
    )
  end
end
