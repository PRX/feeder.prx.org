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

  def single_rollups(downloads, label = I18n.t(".helpers.label.metrics.chart.all_episodes"))
    {
      rollups: downloads,
      label: label
    }
  end
end
