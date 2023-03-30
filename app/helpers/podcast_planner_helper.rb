# frozen_string_literal: true

module PodcastPlannerHelper
  PERIODIC_WEEKS = I18n.t([:every_one, :every_two, :every_three, :every_four], scope: [:podcast_planner, :helper, :period_options]).freeze
  MONTHLY_WEEKS = I18n.t([:first, :second, :third, :fourth, :fifth], scope: [:podcast_planner, :helper, :monthly_options]).freeze

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
end
