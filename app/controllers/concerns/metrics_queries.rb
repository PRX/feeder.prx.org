require "active_support/concern"

module MetricsQueries
  extend ActiveSupport::Concern

  def alltime_downloads(model)
    model_id, column = model_attrs(model)

    Rollups::HourlyDownload
      .where("#{column}": model_id)
      .select(column, "SUM(count) AS count")
      .group(column)
      .final
      .load_async
  end

  def daterange_downloads(model, date_start = Date.utc_today - 28.days, date_end = Date.utc_today, interval = "DAY")
    model_id, column = model_attrs(model)

    Rollups::HourlyDownload
      .where("#{column}": model_id, hour: (date_start..date_end))
      .select("DATE_TRUNC('#{interval}', hour) AS hour", "SUM(count) AS count")
      .group("DATE_TRUNC('#{interval}', hour) AS hour")
      .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
      .final
      .load_async
  end

  def model_attrs(model)
    model_id = if model.is_a?(Podcast)
      model[:id]
    elsif model.is_a?(Episode)
      model[:guid]
    end

    column = "#{model.class.to_s.downcase}_id"

    [model_id, column]
  end
end
