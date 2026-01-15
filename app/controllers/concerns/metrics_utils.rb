require "active_support/concern"

module MetricsUtils
  extend ActiveSupport::Concern

  def check_clickhouse
    unless clickhouse_connected?
      render partial: "metrics/error_card", locals: {
        metrics_path: parse_turbo_frame_id(params),
        error_message: clickhouse_error_message(params)
      }
    end
  end

  def render_metrics_error
    render partial: "metrics/error_card", locals: {
      metrics_path: parse_turbo_frame_id(params),
      error_message: metrics_error_message(params)
    }
  end

  def metrics_error_message(params)
    blank_type = %i[episode_sparkline episode_trend]

    unless blank_type.include?(params[:action].to_sym)
      "general"
    end
  end

  def clickhouse_error_message(params)
    blank_type = %i[episode_sparkline episode_trend]

    unless blank_type.include?(params[:action].to_sym)
      "database"
    end
  end

  def parse_turbo_frame_id(params)
    if params[:action] == "score_card"
      "score_card_#{params[:score_type]}"
    elsif params[:action] == "episode_sparkline"
      "episode_sparkline_#{params[:episode_id]}"
    elsif params[:action] == "episode_trend"
      "episode_trend_#{params[:episode_id]}"
    else
      params[:action]
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

  def mid_blue
    "#c9e9fa"
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
        mid_blue
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
