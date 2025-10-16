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

  def agents_rollups(all_time, over_time)
    all_time.to_enum(:each_with_index).map do |agent, i|
      {
        all_time: agent[:count],
        rollups: over_time.select do |r|
          r["code"] == agent[:code]
        end,
        color: colors[i],
        label: agent.label
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
end
