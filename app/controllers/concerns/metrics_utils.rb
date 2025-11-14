require "active_support/concern"

module MetricsUtils
  extend ActiveSupport::Concern

  def check_clickhouse
    unless clickhouse_connected?
      render partial: "metrics/error_card", locals: {
        metrics_path: params[:action]
      }
    end
  end

  def generate_date_range(date_start, date_end, interval)
    start_range = date_start.to_datetime.utc.send(:"beginning_of_#{interval.downcase}")
    end_range = date_end.to_datetime.utc.send(:"beginning_of_#{interval.downcase}")
    range = []
    i = 0

    while start_range + i.send(:"#{interval.downcase.pluralize}") <= end_range
      range << start_range + i.send(:"#{interval.downcase.pluralize}")
      i += 1
    end

    range
  end

  def colors
    [
      "#007EB2",
      "#FF9600",
      "#75BBE1",
      "#FFC107",
      "#6F42C1",
      "#DC3545",
      "#198754",
      "#D63384",
      "#20C997",
      "#555555"
    ]
  end

  def primary_blue
    "#0072a3"
  end

  def single_rollups(downloads, label = I18n.t(".helpers.label.metrics.chart.all_episodes"))
    {
      rollups: downloads,
      color: primary_blue,
      label: label
    }
  end

  def multiple_episode_rollups(episodes, rollups, totals)
    episodes.to_enum(:each_with_index).map do |episode, i|
      {
        episode: episode,
        rollups: rollups.select do |r|
          r["episode_id"] == episode.guid
        end,
        totals: totals.select do |r|
          r["episode_id"] == episode.guid
        end,
        color: colors[i]
      }
    end
  end

  def minimum_interval(interval)
    if interval == "HOUR"
      "DAY"
    else
      interval
    end
  end

  def dates_from_preset(preset, episode = nil)
    date_start = if date_start_from_preset(preset)
      date_start_from_preset(preset)
    elsif episode
      episode.first_publish_utc_date
    else
      Date.utc_today - 1.day
    end

    date_end = date_end_from_preset(preset, date_start)

    [date_start, guard_date_end(date_end)]
  end

  def date_start_from_preset(preset)
    type, count, interval = preset.to_s.split("_")

    if type == "last"
      count.to_i.send(interval).ago.utc_date
    elsif type == "previous"
      (Date.utc_today - count.to_i.send(interval)).send(:"beginning_of_#{interval.singularize}")
    elsif type == "todate"
      Date.utc_today.send(:"beginning_of_#{interval.singularize}")
    end
  end

  def date_end_from_preset(preset, date_start)
    type, count, interval = preset.to_s.split("_")

    if type == "drop"
      date_start + count.to_i.send(interval)
    elsif type == "previous"
      (date_start + (count.to_i - 1).send(interval)).send(:"end_of_#{interval.singularize}")
    else
      Date.utc_today
    end
  end

  def guard_date_end(date_end)
    if date_end > Date.utc_today
      Date.utc_today
    else
      date_end
    end
  end
end
