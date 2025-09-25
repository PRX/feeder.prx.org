require "active_support/concern"

module MetricsQueries
  extend ActiveSupport::Concern
  include MetricsUtils

  def downloads_date_range_query(model, date_start, date_end, interval)
    model_column, model_id = set_model_vars(model)

    Rollups::HourlyDownload
      .where("#{model_column}": model_id, hour: (date_start..date_end))
      .select(model_column.to_s, "DATE_TRUNC('#{interval}', hour) AS hour", "SUM(count) AS count")
      .group(model_column.to_s, "DATE_TRUNC('#{interval}', hour) AS hour")
      .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
      .load_async
  end

  def agent_alltime_query(agent, model)
    model_column, model_id = set_model_vars(model)

    Rollups::DailyAgent
      .where("#{model_column}": model_id)
      .select("agent_#{agent}_id AS code", "SUM(count) AS count")
      .group("agent_#{agent}_id AS code")
      .order(Arel.sql("SUM(count) AS count DESC"))
      .limit(10)
      .load_async
  end

  def agent_daterange_query(agent, model, date_start, date_end, interval, alltime)
    model_column, model_id = set_model_vars(model)

    Rollups::DailyAgent
      .where("#{model_column}": model_id, day: (date_start..date_end), "agent_#{agent}_id": alltime.pluck(:code))
      .select("DATE_TRUNC('#{minimum_interval(interval)}', day) AS day", "agent_#{agent}_id AS code", "SUM(count) AS count")
      .group("DATE_TRUNC('#{minimum_interval(interval)}', day) AS day", "agent_#{agent}_id AS code")
      .order(Arel.sql("DATE_TRUNC('#{minimum_interval(interval)}', day) ASC"))
      .load_async
  end

  def set_model_vars(model)
    if model.is_a?(Podcast)
      ["podcast_id", model.id]
    else
      ["episode_id", model.guid]
    end
  end
end
