# frozen_string_literal: true

module PodcastPlannerHelper
  PERIODIC_WEEKS = ["Every week", "Every two weeks", "Every three weeks", "Every four weeks"].freeze
  MONTHLY_WEEKS = ["First", "Second", "Third", "Fourth", "Fifth"].freeze

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
    [["number of episodes", "episodes"], ["end date", "date"]]
  end

  def week_condition_options
    ["monthly", "periodic"]
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
