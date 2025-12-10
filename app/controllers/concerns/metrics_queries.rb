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

  def daterange_downloads(model, date_start = Date.utc_today - 28.days, date_end = Time.now, interval = "DAY")
    model_id, column = model_attrs(model)

    Rollups::HourlyDownload
      .where("#{column}": model_id, hour: (date_start..date_end))
      .select(column, "DATE_TRUNC('#{interval}', hour) AS hour", "SUM(count) AS count")
      .group(column, "DATE_TRUNC('#{interval}', hour) AS hour")
      .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
      .final
      .load_async
  end

  def alltime_downloads_by_month(model)
    model_id, column = model_attrs(model)

    Rollups::HourlyDownload
      .where("#{column}": model_id)
      .select(column, "DATE_TRUNC('MONTH', hour) AS hour", "SUM(count) AS count")
      .group(column, "DATE_TRUNC('MONTH', hour) AS hour")
      .order(Arel.sql("DATE_TRUNC('MONTH', hour) AS hour"))
  end

  def model_attrs(model)
    model_id = if model.is_a?(Enumerable)
      model.pluck(:guid)
    elsif model.is_a?(Podcast)
      model[:id]
    elsif model.is_a?(Episode)
      model[:guid]
    end

    column = if model.is_a?(Enumerable)
      "#{model.first.class.to_s.downcase}_id"
    else
      "#{model.class.to_s.downcase}_id"
    end

    [model_id, column]
  end
end
