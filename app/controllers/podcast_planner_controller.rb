class PodcastPlannerController < ApplicationController
  before_action :set_podcast

  # GET /podcasts/1/planner
  def show
  end

  # PATCH/PUT /podcasts/1/planner
  def update
    planned_dates = calculate_dates(planner_params)
    binding.pry
    # respond_to do |format|
    #   if @podcast.update(podcast_planner_params)
    #     format.html { redirect_to podcast_planner_url(@podcast), notice: "Podcast planner was successfully updated." }
    #   else
    #     format.html { render :edit, status: :unprocessable_entity }
    #   end
    # end
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
      :periodic_weeks,
      :start_date,
      :end_condition,
      :number_of_episodes,
      :end_date,
      :publish_time,
      :segment_count,
      day: [],
      monthly_weeks: []
    )
  end

  def calculate_dates(params)
    start = params[:start_date].to_date
    selected_days = params[:day].reject!(&:blank?).map { |day| day.to_i }
    period = params[:periodic_weeks].to_i
    selected_weeks = params[:monthly_weeks].reject!(&:blank?).map { |week| week.to_i }

    if params[:end_condition] == "episodes"
      if params[:week_condition] == "periodic"
        dates = calculate_periodic_dates(start, selected_days, period)
      elsif params[:week_condition] == "monthly"
        dates = calculate_monthly_dates(start, selected_days, selected_weeks)
      end

      return dates.slice(0, params[:number_of_episodes].to_i)
    elsif params[:end_condition] == "date"
      dates = []

      if params[:week_condition] == "periodic"
        current_day = start

        while current_day <= params[:end_date].to_date
          next_days = calculate_days_of_week(current_day, selected_days)
          dates.concat(next_days)
          current_day += period.weeks
        end
      elsif params[:week_condition] == "monthly"
        current_day = start

        while current_day <= params[:end_date].to_date
          next_days = calculate_days_of_week(current_day, selected_days)
          valid_next_days = next_days.select { |day| selected_weeks.include?(week_of_the_month(day)) }
          dates.concat(next_days)
          current_day += 1.week
        end
      end

      return dates.select { |date| date <= params[:end_date].to_date }
    end
  end

  def calculate_days_of_week(current_day, selected_days)
    dates = []
    7.times do |day|
      dates.push(current_day) if selected_days.include?(current_day.wday)
      current_day += 1.day
    end
    dates
  end

  def calculate_periodic_dates(start_date, selected_days, period)
    dates = []
    current_day = start_date

    while dates.length < params[:number_of_episodes].to_i
      next_days = calculate_days_of_week(current_day, selected_days)
      dates.concat(next_days)
      current_day += period.weeks
    end

    dates
  end

  def calculate_monthly_dates(start_date, selected_days, selected_weeks)
    dates = []
    current_day = start_date

    while dates.length < params[:number_of_episodes].to_i
      next_days = calculate_days_of_week(current_day, selected_days)
      valid_next_days = next_days.select { |day| selected_weeks.include?(week_of_the_month(day)) }
      dates.concat(valid_next_days)
      current_day += 1.week
    end

    dates
  end

  def week_of_the_month(date)
    (date.day.to_f / 7).ceil
  end
end
