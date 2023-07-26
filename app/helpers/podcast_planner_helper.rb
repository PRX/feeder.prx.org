# frozen_string_literal: true

module PodcastPlannerHelper
  MONTHLY_WEEKS = [:first, :second, :third, :fourth, :fifth]
  PERIODIC_WEEKS = [:every_one, :every_two, :every_three, :every_four]
  DATE_CONTROLLER = "date"
  TOGGLE_ACTION = "click->date#toggleSelect"
  RECOUNT_ACTION = "click->count#recount"

  def day_options
    DateTime::DAYNAMES.map.with_index { |day, i| [day, i] }
  end

  def week_options
    monthly = MONTHLY_WEEKS.map { |v| [t("podcast_planner.helper.monthly_options.#{v}"), v] }
    periodic = PERIODIC_WEEKS.map { |v| [t("podcast_planner.helper.period_options.#{v}"), v] }
    monthly + periodic
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
    if date_is_in_month?(day, month)
      data[:controller] = DATE_CONTROLLER
      data[:action] = [TOGGLE_ACTION, RECOUNT_ACTION].join(" ")
    end

    content_tag(:td, class: calendar.td_classes_for(day), data: data) do
      block.call
    end
  end
end
