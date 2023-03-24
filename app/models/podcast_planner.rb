class PodcastPlanner
  attr_accessor :podcast_id, :dates, :selected_days, :week_condition, :period, :monthly_weeks, :start_date, :date_range_condition, :number_of_episodes, :end_date, :publish_time, :segment_count, :generated_dates, :drafts

  def initialize(params = {})
    @dates = params[:generated_dates].try { map { |date| date.to_datetime } }
    @drafts = []
    @podcast_id = params[:podcast_id]
    @start_date = params[:start_date].try(:to_datetime)
    @selected_days = params[:selected_days].try { reject(&:blank?) }.try { map { |day| day.to_i } }
    @period = params[:period].try(:to_i)
    @monthly_weeks = params[:monthly_weeks].try { reject(&:blank?) }.try { map { |week| week.to_i } }
    @date_range_condition = params[:date_range_condition]
    @week_condition = params[:week_condition]
    @number_of_episodes = params[:number_of_episodes].try(:to_i)
    @end_date = params[:end_date].try(:to_datetime)
    @publish_time = params[:publish_time].try(:to_time)
    @segment_count = params[:segment_count].try(:to_i)
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

  def end_date_passed?(date)
    date > @end_date
  end

  def periodic?
    @week_condition == "periodic"
  end

  def monthly?
    @week_condition == "monthly"
  end

  def ready_to_select_weeks?
    if periodic?
      @period.present?
    elsif monthly?
      @monthly_weeks.present?
    else
      false
    end
  end

  def ready_to_select_date_range?
    if date_range_ends_by_episodes?
      @number_of_episodes.present?
    elsif date_range_ends_by_end_date?
      @end_date.present? && @end_date > @start_date
    else
      false
    end
  end

  def ready_to_generate_dates?
    @selected_days.present? &&
      ready_to_select_weeks? &&
      ready_to_select_date_range?
  end

  def generate_dates!
    return unless ready_to_generate_dates?
    @dates = []

    if date_range_ends_by_episodes?
      generate_dates_by_remaining_episodes
    elsif date_range_ends_by_end_date?
      generate_dates_by_end_date
    end
  end

  def select_days_of_week_to_add(current_day)
    dates_to_add = []
    7.times do |day|
      dates_to_add.push(current_day) if @selected_days.include?(current_day.wday)
      current_day += 1.day
    end
    dates_to_add
  end

  def generate_dates_by_remaining_episodes
    current_day = @start_date

    while episodes_remain?
      next_days = select_days_of_week_to_add(current_day)
      if periodic?
        @dates.concat(next_days)
        current_day += @period.weeks
      elsif monthly?
        valid_next_days = next_days.select { |day| @monthly_weeks.include?(week_of_the_month(day)) }
        @dates.concat(valid_next_days)
        current_day += 1.week
      end
    end

    @dates = @dates.slice(0, @number_of_episodes)
  end

  def generate_dates_by_end_date
    current_day = @start_date

    until end_date_passed?(current_day)
      next_days = select_days_of_week_to_add(current_day)
      if periodic?
        @dates.concat(next_days)
        current_day += @period.weeks
      elsif monthly?
        valid_next_days = next_days.select { |day| @monthly_weeks.include?(week_of_the_month(day)) }
        @dates.concat(valid_next_days)
        current_day += 1.week
      end
    end

    @dates.select! { |date| date <= @end_date }
  end

  def week_of_the_month(date)
    (date.day.to_f / 7).ceil
  end

  def ready_to_generate_drafts?
    @dates.present? &&
      @publish_time.present? &&
      @segment_count.present?
  end

  def generate_drafts!
    return unless ready_to_generate_drafts?

    @dates.each do |date|
      @drafts.push(Episode.new(
        podcast_id: @podcast_id,
        released_at: apply_publish_time(date),
        title: generate_default_title(date),
        segment_count: @segment_count
      ))
    end
  end

  def apply_publish_time(date)
    date.change(hour: @publish_time.hour, min: @publish_time.min)
  end

  def generate_default_title(date)
    I18n.l(date, format: :day_and_date).to_s
  end
end
