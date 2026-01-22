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
end
