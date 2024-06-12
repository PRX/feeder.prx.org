class PodcastPlanner
  attr_accessor :podcast_id, :dates, :titles, :selected_days, :week_condition, :period, :monthly_weeks, :start_date, :date_range_condition, :number_of_episodes, :end_date, :publish_time, :publish_time_zone, :segment_count, :medium, :selected_dates, :drafts

  MAX_YEARS = 3

  def initialize(params = {})
    @dates = params[:selected_dates].try(:map, &:to_date)
    @titles = params[:selected_titles]
    @drafts = []
    @podcast_id = params[:podcast_id]
    @feed_ids = params[:feed_ids]&.reject(&:empty?)&.map(&:to_i)
    @start_date = params[:start_date].try(:to_date)
    @selected_days = params[:selected_days].try { reject(&:blank?) }.try { map { |day| day.to_i } }
    @period = params[:period].try(:to_i)
    @monthly_weeks = params[:monthly_weeks].try { reject(&:blank?) }.try { map { |week| week.to_i } }
    @date_range_condition = params[:date_range_condition]
    @week_condition = params[:week_condition]
    @number_of_episodes = params[:number_of_episodes].try(:to_i)
    @end_date = params[:end_date].try(:to_date)
    @publish_time = params[:publish_time]
    @publish_time_zone = params[:publish_time_zone] || ""
    @segment_count = params[:segment_count].try(:to_i)
    @medium = params[:medium]
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

  def week_of_the_month(date)
    (date.day.to_f / 7).ceil
  end

  def days_between(start_date, end_date)
    (end_date - start_date).to_i
  end

  def valid_day_to_add?(current_day)
    @selected_days.include?(current_day.wday)
  end

  def valid_week_to_add?(current_day)
    @monthly_weeks.include?(week_of_the_month(current_day))
  end

  def valid_period?(current_day)
    (days_between(@start_date, current_day) / 7) % @period == 0
  end

  def add_date(current_day)
    if valid_day_to_add?(current_day)
      if periodic? && valid_period?(current_day)
        @dates.push(current_day)
      elsif monthly? && valid_week_to_add?(current_day)
        @dates.push(current_day)
      end
    end
  end

  def past_max_date?(current_day)
    current_day.after?(@start_date + MAX_YEARS.years)
  end

  def generate_dates_by_remaining_episodes
    current_day = @start_date

    while episodes_remain?
      return if past_max_date?(current_day)

      add_date(current_day)
      current_day += 1.day
    end
  end

  def generate_dates_by_end_date
    current_day = @start_date

    until end_date_passed?(current_day)
      return if past_max_date?(current_day)

      add_date(current_day)
      current_day += 1.day
    end
  end

  def ready_to_generate_drafts?
    @dates.present? &&
      @publish_time.present? &&
      (@segment_count.present? || @medium === "video") &&
      @medium.present?
  end

  def generate_drafts!
    return unless ready_to_generate_drafts?

    @dates.zip(@titles || []).each do |date, title|
      @drafts.push(Episode.new(
        podcast_id: @podcast_id,
        feed_ids: @feed_ids,
        released_at: apply_publish_time(date),
        title: generate_default_title(date, title),
        segment_count: @segment_count,
        medium: @medium
      ))
    end
  end

  def apply_publish_time(date)
    zone = ActiveSupport::TimeZone[@publish_time_zone] || ActiveSupport::TimeZone["UTC"]
    zone.parse("#{date.to_date} #{@publish_time}")
  end

  def generate_default_title(date, title)
    if title.present?
      title
    else
      I18n.l(date.to_date, format: :full_month)
    end
  end
end
