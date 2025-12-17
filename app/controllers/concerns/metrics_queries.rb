require "active_support/concern"

module MetricsQueries
  extend ActiveSupport::Concern

  def alltime_downloads(model, select_override = nil)
    model_id, column = model_attrs(model)
    selection = select_override || column

    Rollups::HourlyDownload
      .where("#{column}": model_id)
      .select(selection, "SUM(count) AS count")
      .group(selection)
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

  def downloads_by_feed(model, slugs, date_start = Date.utc_today - 28.days)
    model_id, column = model_attrs(model)

    Rollups::HourlyDownload
      .where("#{column}": model_id, feed_slug: slugs, hour: (date_start..))
      .select(:feed_slug, "SUM(count) AS count")
      .group(:feed_slug)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .load_async
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
