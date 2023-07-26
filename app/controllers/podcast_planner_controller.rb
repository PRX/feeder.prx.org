class PodcastPlannerController < ApplicationController
  before_action :set_podcast
  before_action :set_beginning_of_week

  # GET /podcasts/1/planner
  def show
    @planner = PodcastPlanner.new(planner_params)
    @planner.generate_dates!
    @draft_dates = @podcast.episodes.draft_or_scheduled.pluck(:released_at)
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

  # Make params match PodcastPlanner interface
  def planner_params
    p = permit_params
    p[:podcast_id] = @podcast.id
    p[:date_range_condition] = p[:number_of_episodes].present? ? "episodes" : "date"
    p[:segment_count] = p[:ad_breaks] + 1 if p[:ad_breaks].present?

    # translate selected weeks into monthly weeks
    monthly_weeks = monthly_week_options(p[:selected_weeks])
    periodic_weeks = periodic_week_options(p[:selected_weeks])
    if monthly_weeks.any?
      p[:week_condition] = "monthly"
      p[:monthly_weeks] = monthly_weeks
    elsif periodic_weeks.any?
      p[:week_condition] = "periodic"
      p[:period] = periodic_weeks.first
    end

    p
  end

  # Only allow a list of trusted parameters through.
  def permit_params
    params.permit(
      :start_date,
      :number_of_episodes,
      :end_date,
      :publish_time,
      :medium,
      :ad_breaks,
      selected_days: [],
      selected_weeks: [],
      selected_dates: []
    )
  end

  def monthly_week_options(selected_weeks)
    PodcastPlannerHelper::MONTHLY_WEEKS.filter_map.with_index do |val, idx|
      idx + 1 if selected_weeks&.include?(val.to_s)
    end
  end

  def periodic_week_options(selected_weeks)
    PodcastPlannerHelper::PERIODIC_WEEKS.filter_map.with_index do |val, idx|
      idx + 1 if selected_weeks&.include?(val.to_s)
    end
  end
end
