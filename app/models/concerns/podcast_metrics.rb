require "active_support/concern"

module PodcastMetrics
  extend ActiveSupport::Concern

  include MetricsQueries

  def alltime_downloads
    Rails.cache.fetch("#{cache_key_with_version}/alltime_downloads", expires_in: 1.hour) do
      alltime_downloads_query.sum(&:count)
    end
  end

  def daily_downloads(days: 28, date_start: nil, date_end: nil)
    date_start ||= Time.now - days.days
    date_end ||= default_time_end

    Rails.cache.fetch("#{cache_key_with_version}/daily_downloads", expires_in: 1.hour) do
      daterange_downloads_query(date_start: date_start, date_end: date_end, interval: "DAY")
    end
  end

  def monthly_downloads(months: 12, date_start: nil, date_end: nil)
    date_start = date_start&.beginning_of_month || (Time.now - (months - 1).months).beginning_of_month
    date_end ||= default_time_end

    Rails.cache.fetch("#{cache_key_with_version}/monthly_downloads", expires_in: 1.hour) do
      daterange_downloads_query(date_start: date_start, date_end: date_end, interval: "MONTH").transform_keys { |k| k.to_datetime.utc }
    end
  end

  def downloads_by_episode(guids: recent_published_episode_guids, date_start: nil, date_end: nil)
    date_start ||= default_time_start
    date_end ||= default_time_end

    downloads = daterange_downloads_query(model_id: guids, column: "episode_id", date_start: date_start, date_end: date_end)

    guids.map do |guid|
      {
        episode: Episode.find_by(guid: guid),
        rollups: downloads.select do |k, v|
          k[0] == guid
        end.transform_keys { |k| k[1] }.to_a
      }
    end
  end

  def recent_published_episode_guids(limit: 10)
    episodes.published.dropdate_desc.limit(limit).pluck(:guid)
  end

  def feed_downloads
    Rails.cache.fetch("#{cache_key_with_version}/feed_downloads", expires_in: 1.hour) do
      feed_downloads_query(id, "podcast_id", feeds)
    end
  end

  def feed_download_rollups
    sorted_feed_download_rollups(feeds, feed_downloads)
  end

  def published_seasons
    episodes.published.dropdate_desc.pluck(:season_number).uniq.compact
  end

  def latest_season
    published_seasons.first
  end

  def season_download_rollups
    published_seasons.map do |season|
      {
        season_number: season,
        downloads: downloads_by_season(season)[id]
      }
    end.sort { |a, b| b[:downloads] <=> a[:downloads] }
  end

  def downloads_by_season(season_number)
    season_episodes_guids = episodes.published.where(season_number: season_number).pluck(:guid)
    expiration = (season_number == latest_season) ? 1.hour : 1.month

    Rails.cache.fetch("#{cache_key_with_version}/downloads_by_season/#{season_number}", expires_in: expiration) do
      Rollups::HourlyDownload
        .where(episode_id: season_episodes_guids)
        .group(:podcast_id)
        .final
        .sum(:count)
    end
  end

  def top_countries_downloads
    Rails.cache.fetch("#{cache_key_with_version}/top_countries_downloads", expires_in: 1.hour) do
      top_countries_downloads_query(id, "podcast_id")
    end
  end

  def other_countries_downloads
    Rails.cache.fetch("#{cache_key_with_version}/other_countries_downloads", expires_in: 1.hour) do
      other_countries_downloads_query(id, "podcast_id", top_countries_downloads)
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
      top_agents_downloads_query(id, "podcast_id")
    end
  end

  def other_agents_downloads
    Rails.cache.fetch("#{cache_key_with_version}/other_agents_downloads", expires_in: 1.hour) do
      other_agents_downloads_query(id, "podcast_id", top_agents_downloads)
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
