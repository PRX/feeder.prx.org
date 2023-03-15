class PodcastPlanner
  attr_accessor :dates, :selected_days, :week_condition, :period, :monthly_weeks, :start_date, :date_range_condition, :number_of_episodes, :end_date

  def initialize(params = {})
    @dates = []
    @start_date = params[:start_date].try(:to_date)
    @selected_days = params[:days].try { reject!(&:blank?) }.try { map { |day| day.to_i } }
    @period = params[:period].try(:to_i)
    @monthly_weeks = params[:monthly_weeks].try { reject!(&:blank?) }.try { map { |week| week.to_i } }
    @date_range_condition = params[:date_range_condition]
    @week_condition = params[:week_condition]
    @number_of_episodes = params[:number_of_episodes].try(:to_i)
    @end_date = params[:end_date].try(:to_date)
  end

  def date_range_ends_by_episodes?
    @date_range_condition == "episodes"
  end

  def date_range_ends_by_end_date?
    @date_range_condition == "date"
  end

  def episodes_remain?
    @dates.length < @number_of_episodes
  end

  def end_date_reached?(date)
    date >= @end_date
  end

  def periodic?
    @week_condition == "periodic"
  end

  def monthly?
    @week_condition == "monthly"
  end

  def generate_dates!
    @dates = []
    if date_range_ends_by_episodes?
      calculate_dates_by_remaining_episodes
    elsif date_range_ends_by_end_date?
      calculate_dates_by_end_date
    end
  end

  def calculate_days_of_week(current_day)
    dates_to_add = []
    7.times do |day|
      dates_to_add.push(current_day) if @selected_days.include?(current_day.wday)
      current_day += 1.day
    end
    dates_to_add
  end

  def calculate_dates_by_remaining_episodes
    current_day = @start_date

    while episodes_remain?
      next_days = calculate_days_of_week(current_day)
      if periodic?
        @dates.concat(next_days)
        current_day += @period.weeks
      elsif monthly?
        valid_next_days = next_days.select { |day| @monthly_weeks.include?(week_of_the_month(day)) }
        @dates.concat(valid_next_days)
        current_day += 1.week
      end
    end

    @dates = @dates.slice!(0, @number_of_episodes)
  end

  def calculate_dates_by_end_date
    current_day = @start_date

    until end_date_reached?(current_day)
      next_days = calculate_days_of_week(current_day)
      if periodic?
        @dates.concat(next_days)
        current_day += @period.weeks
      elsif monthly?
        valid_next_days = next_days.select { |day| @monthly_weeks.include?(week_of_the_month(day)) }
        @dates.concat(valid_next_days)
        current_day += 1.week
      end
    end

    @dates = @dates.select { |date| date <= @end_date }
  end

  def week_of_the_month(date)
    (date.day.to_f / 7).ceil
  end
end
