require "active_support/concern"

module MetricsQueries
  extend ActiveSupport::Concern

  def alltime_downloads_query(model_id, column, select_override = nil)
    selection = select_override || column

    Rollups::HourlyDownload
      .where("#{column}": model_id)
      .select(selection, "SUM(count) AS count")
      .group(selection)
      .final
      .load_async
  end

  def daterange_downloads_query(model_id, column, date_start = default_time_start, date_end = default_time_end, interval = "DAY")
    Rollups::HourlyDownload
      .where("#{column}": model_id, hour: (date_start..date_end))
      .select(column, "DATE_TRUNC('#{interval}', hour) AS hour", "SUM(count) AS count")
      .group(column, "DATE_TRUNC('#{interval}', hour) AS hour")
      .order(Arel.sql("DATE_TRUNC('#{interval}', hour) ASC"))
      .final
      .load_async
  end

  def feed_downloads_query(model_id, column, feeds, date_start = default_time_start, date_end = default_time_end)
    slugs = feeds.pluck(:slug).map { |slug| slug.nil? ? "" : slug }

    Rollups::HourlyDownload
      .where("#{column}": model_id, feed_slug: slugs, hour: (date_start..date_end))
      .select(:feed_slug, "SUM(count) AS count")
      .group(:feed_slug)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .load_async
      .pluck(:feed_slug, Arel.sql("SUM(count) AS count"))
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
      .select(:country_code, "SUM(count) AS count")
      .group(:country_code)
      .order(Arel.sql("SUM(count) AS count DESC"))
      .final
      .limit(10)
      .load_async
      .pluck(:country_code, Arel.sql("SUM(count) AS count"))
  end

  def other_countries_downloads_query(model_id, column, excluded_countries, date_start = default_date_start.to_s, date_end = default_date_end.to_s)
    ex_country_codes = excluded_countries.map { |c| c[0] }

    Rollups::DailyGeo
      .where("#{column}": model_id, day: date_start..date_end)
      .where.not(country_code: ex_country_codes)
      .select("'Other' AS country_code", "SUM(count) AS count")
      .final
      .load_async
      .pluck(Arel.sql("'Other' AS country_code"), Arel.sql("SUM(count) AS count"))
  end

  def top_agents_downloads
    model_id, column = model_attrs
    date_start = (Date.utc_today - 28.days).to_s
    date_end = Date.utc_today.to_s

    Rails.cache.fetch("#{cache_key_with_version}/top_agents_downloads", expires_in: 1.day) do
      Rollups::DailyAgent
        .where("#{column}": model_id, day: date_start..date_end)
        .select("agent_name_id AS code", "SUM(count) AS count")
        .group("agent_name_id AS code")
        .order(Arel.sql("SUM(count) AS count DESC"))
        .final
        .limit(10)
        .load_async
        .pluck(Arel.sql("agent_name_id AS code"), Arel.sql("SUM(count) AS count"))
    end
  end

  def other_agents_downloads(top_agents)
    model_id, column = model_attrs
    date_start = (Date.utc_today - 28.days).to_s
    date_end = Date.utc_today.to_s
    top_agent_codes = top_agents.map { |c| c[0] }

    Rails.cache.fetch("#{cache_key_with_version}/other_agents_downloads", expires_in: 1.day) do
      Rollups::DailyAgent
        .where("#{column}": model_id, day: date_start..date_end)
        .where.not(agent_name_id: top_agent_codes)
        .select("'Other' AS country_code", "SUM(count) AS count")
        .final
        .load_async
        .pluck(Arel.sql("'Other' AS country_code"), Arel.sql("SUM(count) AS count"))
    end
  end

  def agent_download_rollups
    top_agents_downloads.concat(other_agents_downloads(top_agents_downloads)).map do |agent|
      {
        label: Rollups::DailyAgent.label_for(agent[0]),
        downloads: agent[1]
      }
    end
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

  private

  def model_attrs
    model_id = if is_a?(Podcast)
      id
    elsif is_a?(Episode)
      guid
    end

    column = "#{self.class.to_s.downcase}_id"

    [model_id, column]
  end
end
