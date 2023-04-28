class PodcastPlannerController < ApplicationController
  before_action :set_podcast
  before_action :set_beginning_of_week

  # GET /podcasts/1/planner
  def show
    @planner = PodcastPlanner.new(planner_params)
    @planner.generate_dates!
    @draft_dates = @podcast.episodes.draft.pluck(:released_at)
  end

  # POST /podcasts/1/planner
  def create
    @planner = PodcastPlanner.new(planner_params)
    @planner.generate_drafts!

    respond_to do |format|
      if @planner.drafts.each { |episode| episode.save! }
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

  def set_beginning_of_week
    Date.beginning_of_week = :sunday
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
      monthly_weeks: [],
      selected_dates: []
    )
  end
end
