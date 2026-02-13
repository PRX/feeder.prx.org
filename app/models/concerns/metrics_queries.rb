require "active_support/concern"

module MetricsQueries
  extend ActiveSupport::Concern

  METRICS_CACHE_VERSION = 1

  def alltime_downloads_query(model_id: metrics_default_id, column: metrics_default_column)
    Rollups::HourlyDownload
      .where("#{column}": model_id)
      .select(column, "SUM(count) AS count")
      .group(column)
      .final
  end

  def daterange_downloads_query(model_id: metrics_default_id, column: metrics_default_column, date_start: metrics_default_time_start, date_end: metrics_default_time_end, interval: "DAY")
    if model_id.is_a?(Array)
      Rollups::HourlyDownload
        .where("#{column}": model_id, hour: (date_start..date_end))
        .group(column, "DATE_TRUNC('#{interval}', hour)")
        .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
        .final
        .sum(:count)
    else
      Rollups::HourlyDownload
        .where("#{column}": model_id, hour: (date_start..date_end))
        .group("DATE_TRUNC('#{interval}', hour)")
        .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
        .final
        .sum(:count)
    end
  end

  def feed_downloads_query(feeds:, model_id: metrics_default_id, column: metrics_default_column, date_start: metrics_default_time_start, date_end: metrics_default_time_end)
    slugs = feeds.pluck(:slug).map { |slug| slug.nil? ? "" : slug }

    Rollups::HourlyDownload
      .where("#{column}": model_id, feed_slug: slugs, hour: (date_start..date_end))
      .group(:feed_slug)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .sum(:count)
  end

  def top_countries_downloads_query(model_id: metrics_default_id, column: metrics_default_column, date_start: metrics_default_date_start, date_end: metrics_default_date_end)
    Rollups::DailyGeo
      .where("#{column}": model_id, day: date_start..date_end)
      .group(:country_code)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .limit(10)
      .sum(:count)
  end

  def other_countries_downloads_query(excluded_countries:, model_id: metrics_default_id, column: metrics_default_column, date_start: metrics_default_date_start, date_end: metrics_default_date_end)
    ex_country_codes = excluded_countries.map { |c| c[0] }

    Rollups::DailyGeo
      .where("#{column}": model_id, day: date_start..date_end)
      .where.not(country_code: ex_country_codes)
      .final
      .sum(:count)
  end

  def top_agents_downloads_query(model_id: metrics_default_id, column: metrics_default_column, date_start: metrics_default_date_start, date_end: metrics_default_date_end)
    Rollups::DailyAgent
      .where("#{column}": model_id, day: date_start..date_end)
      .group(:agent_name_id)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .limit(10)
      .sum(:count)
  end

  def other_agents_downloads_query(excluded_agents:, model_id: metrics_default_id, column: metrics_default_column, date_start: metrics_default_date_start, date_end: metrics_default_date_end)
    ex_agent_codes = excluded_agents.map { |c| c[0] }

    Rollups::DailyAgent
      .where("#{column}": model_id, day: date_start..date_end)
      .where.not(agent_name_id: ex_agent_codes)
      .final
      .sum(:count)
  end

  def metrics_cache_key
    "#{cache_key}/metrics_v#{METRICS_CACHE_VERSION}"
  end

  private

  def metrics_default_date_start
    (Date.utc_today - 28.days)
  end

  def metrics_default_date_end
    Date.utc_today
  end

  def metrics_default_time_start
    Time.now - 28.days
  end

  def metrics_default_time_end
    Time.now
  end

  def metrics_default_id
    if is_a?(Podcast)
      id
    elsif is_a?(Episode)
      guid
    end
  end

  def metrics_default_column
    if is_a?(Podcast)
      "podcast_id"
    elsif is_a?(Episode)
      "episode_id"
    end
  end
end
