require "active_support/concern"

module MetricsQueries
  extend ActiveSupport::Concern

  def alltime_downloads_query(model_id, column)
    Rollups::HourlyDownload
      .where("#{column}": model_id)
      .select(column, "SUM(count) AS count")
      .group(column)
      .final
  end

  def daterange_downloads_query(model_id, column, date_start = default_time_start, date_end = default_time_end, interval = "DAY")
    Rollups::HourlyDownload
      .where("#{column}": model_id, hour: (date_start..date_end))
      .select(column, "DATE_TRUNC('#{interval}', hour) AS hour", "SUM(count) AS count")
      .group(column, "DATE_TRUNC('#{interval}', hour) AS hour")
      .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
      .final
  end

  def feed_downloads_query(model_id, column, feeds, date_start = default_time_start, date_end = default_time_end)
    slugs = feeds.pluck(:slug).map { |slug| slug.nil? ? "" : slug }

    Rollups::HourlyDownload
      .where("#{column}": model_id, feed_slug: slugs, hour: (date_start..date_end))
      .group(:feed_slug)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .sum(:count)
  end

  def sorted_feed_download_rollups(feeds, feed_downloads)
    feed_rollups = feeds.map do |feed|
      slug = feed[:slug].nil? ? "" : feed[:slug]
      downloads = feed_downloads.to_h[slug] || 0

      {
        feed: feed,
        downloads: downloads
      }
    end

    feed_rollups.sort { |a, b| b[:downloads] <=> a[:downloads] }
  end

  def top_countries_downloads_query(model_id, column, date_start = default_date_start.to_s, date_end = default_date_end.to_s)
    Rollups::DailyGeo
      .where("#{column}": model_id, day: date_start..date_end)
      .group(:country_code)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .limit(10)
      .sum(:count)
  end

  def other_countries_downloads_query(model_id, column, excluded_countries, date_start = default_date_start.to_s, date_end = default_date_end.to_s)
    ex_country_codes = excluded_countries.map { |c| c[0] }

    Rollups::DailyGeo
      .where("#{column}": model_id, day: date_start..date_end)
      .where.not(country_code: ex_country_codes)
      .final
      .sum(:count)
  end

  def top_agents_downloads_query(model_id, column, date_start = default_date_start, date_end = default_date_end)
    Rollups::DailyAgent
      .where("#{column}": model_id, day: date_start..date_end)
      .group(:agent_name_id)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .limit(10)
      .sum(:count)
  end

  def other_agents_downloads_query(model_id, column, excluded_agents, date_start = default_date_start, date_end = default_date_end)
    ex_agent_codes = excluded_agents.map { |c| c[0] }

    Rollups::DailyAgent
      .where("#{column}": model_id, day: date_start..date_end)
      .where.not(agent_name_id: ex_agent_codes)
      .final
      .sum(:count)
  end

  def default_date_start
    (Date.utc_today - 28.days)
  end

  def default_date_end
    Date.utc_today
  end

  def default_time_start
    Time.now - 28.days
  end

  def default_time_end
    Time.now
  end
end
