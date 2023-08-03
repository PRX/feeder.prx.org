# frozen_string_literal: true

module PodcastPlannerHelper
  MONTHLY_WEEKS = [:first, :second, :third, :fourth, :fifth]
  PERIODIC_WEEKS = [:every_one, :every_two, :every_three, :every_four]
  CALENDAR_TARGET = "container"
  TOGGLE_ACTION = "click->calendar#toggleSelect"
  RECOUNT_ACTION = "click->planner#recount"

  def day_options
    DateTime::DAYNAMES.map.with_index { |day, i| [day, i] }
  end

  def week_options
    monthly = MONTHLY_WEEKS.map { |v| [t("podcast_planner.helper.monthly_options.#{v}"), v] }
    periodic = PERIODIC_WEEKS.map { |v| [t("podcast_planner.helper.period_options.#{v}"), v] }
    monthly + periodic
  end

  def time_options
    epoch = Time.at(0).utc
    24.times.flat_map do |hour|
      [0, 30].map do |minute|
        time = epoch.change(hour: hour, min: minute)
        [I18n.l(time, format: :time_12_hour), time.to_i]
      end
    end
  end

  def days_in_month(month)
    month.map { |d| d.day }
  end

  def date_is_in_dates?(date, dates)
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
    cls = calendar.td_classes_for(day)

    if date_is_in_month?(day, month)
      data[:calendar_target] = CALENDAR_TARGET
      data[:action] = [TOGGLE_ACTION, RECOUNT_ACTION].join(" ")
    end

    content_tag(:td, class: cls, data: data) do
      block.call
    end
  end
end
