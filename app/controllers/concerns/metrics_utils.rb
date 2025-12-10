require "active_support/concern"

module MetricsUtils
  extend ActiveSupport::Concern

  def check_clickhouse
    unless clickhouse_connected?
      render partial: "metrics/error_card", locals: {
        metrics_path: params[:action],
        card_type: card_type(params[:action].to_sym)
      }
    end
  end

  def card_type(action)
    blank_type = %i[episode_sparkline]

    if blank_type.include?(action)
      "blank"
    else
      "error"
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

  def light_pink
    "#e7d4ff"
  end

  def light_blue
    "#aafff5"
  end

  def orange
    "#ff9601"
  end

  def single_rollups(downloads, label = I18n.t(".helpers.label.metrics.chart.all_episodes"))
    {
      rollups: downloads,
      color: light_blue,
      label: label
    }
  end

  def multiple_episode_rollups(episodes, rollups)
    episodes.map.with_index do |episode, i|
      color = if i == 0
        orange
      else
        light_blue
      end
      {
        episode: episode,
        rollups: rollups.select do |r|
          r["episode_id"] == episode.guid
        end,
        color: color
      }
    end
  end
end
