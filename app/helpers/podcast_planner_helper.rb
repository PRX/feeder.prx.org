# frozen_string_literal: true

module PodcastPlannerHelper
  PERIODIC_WEEKS = I18n.t([:every_one, :every_two, :every_three, :every_four], scope: [:podcast_planner, :helper, :period_options]).freeze
  MONTHLY_WEEKS = I18n.t([:first, :second, :third, :fourth, :fifth], scope: [:podcast_planner, :helper, :monthly_options]).freeze
  CALENDAR_CONTROLLER = "calendar"
  TOGGLE_ACTION = "click->calendar#toggleSelect"
  HIGHLIGHT_ACTION = "mouseover->calendar#highlight"
  UNHIGHLIGHT_ACTION = "mouseout->calendar#unhighlight"

  def day_options
    DateTime::DAYNAMES.map.with_index { |day, i| [day, i] }
  end

  def periodic_weeks_options
    PERIODIC_WEEKS.map.with_index { |opt, i| [opt, i + 1] }
  end

  def monthly_weeks_options
    MONTHLY_WEEKS.map.with_index { |opt, i| [opt, i + 1] }
  end

  def end_condition_options
    [[I18n.t(".podcast_planner.helper.episodes"), "episodes"],
      [I18n.t(".podcast_planner.helper.end_date"), "date"]]
  end

  def week_condition_options
    [[I18n.t(".podcast_planner.helper.month"), "monthly"],
      [I18n.t(".podcast_planner.helper.period"), "periodic"]]
  end

  def time_options
    opts = []
    24.times do |hour|
      time = Time.new
      opts.push(time.change({hour: hour}))
      opts.push(time.change({hour: hour, min: 30}))
    end

    opts.map { |opt| [I18n.l(opt, format: :time_12_hour), opt] }
  end

  def days_in_month(month)
    month.map { |d| d.day }
  end

  def is_preselected_date?(date, dates)
    if dates.present?
      dates.include?(date)
    else
      false
    end
  end

  def date_is_in_month?(date, month)
    date.month == month
  end

  def calendar_day_tag(day:, month:, calendar:, &block)
    data = {}
    if date_is_in_month?(day, month)
      data[:controller] = CALENDAR_CONTROLLER
      data[:action] = [TOGGLE_ACTION, HIGHLIGHT_ACTION, UNHIGHLIGHT_ACTION].join(" ")
    end

    content_tag(:td, class: calendar.td_classes_for(day), data: data) do
      block.call
    end
  end
end
