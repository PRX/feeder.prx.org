require "active_support/concern"

module MetricsUtils
  extend ActiveSupport::Concern

  def check_clickhouse
    unless clickhouse_connected?
      render partial: "metrics/error_card", locals: {
        metrics_path: parse_turbo_frame_id,
        error_message: clickhouse_error_message
      }
    end
  end

  def render_metrics_error
    render partial: "metrics/error_card", locals: {
      metrics_path: parse_turbo_frame_id,
      error_message: metrics_error_message
    }
  end

  def metrics_error_message
    blank_type = %i[episode_sparkline episode_trend]

    unless blank_type.include?(action_name.to_sym)
      "general"
    end
  end

  def clickhouse_error_message
    blank_type = %i[episode_sparkline episode_trend]

    unless blank_type.include?(action_name.to_sym)
      "database"
    end
  end

  def parse_turbo_frame_id
    if action_name == "score_card"
      "score_card_#{params[:score_type]}"
    elsif action_name == "episode_sparkline"
      "episode_sparkline_#{params[:episode_id]}"
    elsif action_name == "episode_trend"
      "episode_trend_#{params[:episode_id]}"
    else
      action_name
    end
  end
end
