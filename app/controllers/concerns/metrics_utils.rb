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
end
