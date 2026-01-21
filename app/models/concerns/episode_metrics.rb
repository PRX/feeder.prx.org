require "active_support/concern"

module EpisodeMetrics
  extend ActiveSupport::Concern

  include MetricsQueries

  def previous_trend_episode
    if feeds.include?(podcast.default_feed) && first_rss_published_at.present?
      podcast.default_feed.episodes.published.dropdate_desc.where("episodes.first_rss_published_at IS NOT NULL AND episodes.first_rss_published_at < ?", first_rss_published_at).first
    end
  end

  def dropday_sum
    return nil unless first_rss_published_at.present?
    return nil if (first_rss_published_at + 1.day) > Time.now

    Rails.cache.fetch("#{cache_key_with_version}/dropday_sum", expires_in: 28.days) do
      lowerbound = first_rss_published_at.beginning_of_hour
      upperbound = lowerbound + 24.hours

      daterange_downloads_query(date_start: lowerbound, date_end: upperbound).values.sum
    end
  end

  def episode_trend
    return nil unless first_rss_published_at.present? && previous_trend_episode.present?
    return nil if (first_rss_published_at + 1.day) > Time.now

    current_sum = dropday_sum
    previous_sum = previous_trend_episode.dropday_sum

    return nil if current_sum <= 0 || previous_sum <= 0

    ((current_sum.to_f / previous_sum.to_f) - 1).round(3)
  end

  def sparkline_downloads
    return nil unless publish_hour.present?

    Rails.cache.fetch("#{cache_key_with_version}/sparkline_downloads", expires_in: 28.days) do
      daterange_downloads_query(date_start: publish_hour, date_end: publish_hour + 28.days, interval: "DAY")
    end
  end

  def publish_hour
    if first_rss_published_at.present?
      first_rss_published_at.beginning_of_hour
    else
      published_at.beginning_of_hour
    end
  end

  def alltime_downloads
    alltime_downloads_query.sum(&:count)
  end

  def daily_downloads(days: 28, date_start: nil, date_end: nil)
    date_start ||= Time.now - days.days
    date_end ||= default_time_end

    Rails.cache.fetch("#{cache_key_with_version}/daily_downloads", expires_in: 1.hour) do
      daterange_downloads_query(date_start: date_start, date_end: date_end, interval: "DAY")
    end
  end

  def feed_downloads
    Rails.cache.fetch("#{cache_key_with_version}/feed_downloads", expires_in: 1.hour) do
      feed_downloads_query(guid, "episode_id", feeds)
    end
  end

  def feed_download_rollups
    sorted_feed_download_rollups(feeds, feed_downloads)
  end

  def top_countries_downloads
    Rails.cache.fetch("#{cache_key_with_version}/top_countries_downloads", expires_in: 1.hour) do
      top_countries_downloads_query(guid, "episode_id")
    end
  end

  def other_countries_downloads
    Rails.cache.fetch("#{cache_key_with_version}/other_countries_downloads", expires_in: 1.hour) do
      other_countries_downloads_query(guid, "episode_id", top_countries_downloads)
    end
  end

  def country_download_rollups
    all_countries = top_countries_downloads.merge({other: other_countries_downloads})
    all_countries.to_a.map do |country|
      {
        label: Rollups::DailyGeo.label_for(country[0]),
        downloads: country[1]
      }
    end
  end

  def top_agents_downloads
    Rails.cache.fetch("#{cache_key_with_version}/top_agents_downloads", expires_in: 1.hour) do
      top_agents_downloads_query(guid, "episode_id")
    end
  end

  def other_agents_downloads
    Rails.cache.fetch("#{cache_key_with_version}/other_agents_downloads", expires_in: 1.hour) do
      other_agents_downloads_query(guid, "episode_id", top_agents_downloads)
    end
  end

  def agent_download_rollups
    all_agents = top_agents_downloads.merge({other: other_agents_downloads})
    all_agents.to_a.map do |agent|
      {
        label: Rollups::DailyAgent.label_for(agent[0]),
        downloads: agent[1]
      }
    end
  end
end
