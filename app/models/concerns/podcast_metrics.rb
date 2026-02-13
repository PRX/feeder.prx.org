require "active_support/concern"

module PodcastMetrics
  extend ActiveSupport::Concern

  include MetricsQueries

  def alltime_downloads
    Rails.cache.fetch("#{metrics_cache_key}/alltime_downloads", expires_in: 1.hour) do
      alltime_downloads_query.sum(&:count)
    end
  end

  def daily_downloads(days: 28, date_start: nil, date_end: nil)
    date_start ||= Time.now - days.days
    date_end ||= Time.now

    Rails.cache.fetch("#{metrics_cache_key}/daily_downloads", expires_in: 1.hour) do
      daterange_downloads_query(date_start: date_start, date_end: date_end, interval: "DAY")
    end
  end

  def monthly_downloads(months: 12, date_start: nil, date_end: nil)
    date_start = date_start&.beginning_of_month || (Time.now - (months - 1).months).beginning_of_month
    date_end ||= Time.now

    Rails.cache.fetch("#{metrics_cache_key}/monthly_downloads", expires_in: 1.hour) do
      daterange_downloads_query(date_start: date_start, date_end: date_end, interval: "MONTH").transform_keys { |k| k.to_datetime.utc }
    end
  end

  def downloads_by_episode(guids: recent_published_episode_guids, date_start: nil, date_end: nil)
    date_start ||= Time.now - 28.days
    date_end ||= Time.now

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
    feed_labels = feeds.map do |feed|
      [feed.slug, feed.label]
    end.to_h

    Rails.cache.fetch("#{metrics_cache_key}/feed_downloads", expires_in: 1.hour) do
      feed_downloads_query(feeds: feeds)
    end.transform_keys { |k| feed_labels[k.presence] }
  end

  def published_seasons
    episodes.published.dropdate_desc.pluck(:season_number).uniq.compact
  end

  def latest_season
    published_seasons.first
  end

  def season_download_rollups
    published_seasons.map do |season|
      downloads_by_season(season_number: season).to_a.flatten
    end
  end

  def downloads_by_season(season_number:)
    season_episodes_guids = episodes.published.where(season_number: season_number).pluck(:guid)
    expiration = (season_number == latest_season) ? 1.hour : 1.month

    Rails.cache.fetch("#{metrics_cache_key}/downloads_by_season/#{season_number}", expires_in: expiration) do
      Rollups::HourlyDownload
        .where(episode_id: season_episodes_guids)
        .group(:podcast_id)
        .final
        .sum(:count)
    end.transform_keys { |k| "Season #{season_number}" }
  end

  def top_countries_downloads
    Rails.cache.fetch("#{metrics_cache_key}/top_countries_downloads", expires_in: 1.hour) do
      top_countries_downloads_query
    end
  end

  def other_countries_downloads
    Rails.cache.fetch("#{metrics_cache_key}/other_countries_downloads", expires_in: 1.hour) do
      other_countries_downloads_query(excluded_countries: top_countries_downloads)
    end
  end

  def country_download_rollups
    all_countries = top_countries_downloads.merge({other: other_countries_downloads})

    all_countries.transform_keys { |k| Rollups::DailyGeo.label_for(k) }
  end

  def top_agents_downloads
    Rails.cache.fetch("#{metrics_cache_key}/top_agents_downloads", expires_in: 1.hour) do
      top_agents_downloads_query
    end
  end

  def other_agents_downloads
    Rails.cache.fetch("#{metrics_cache_key}/other_agents_downloads", expires_in: 1.hour) do
      other_agents_downloads_query(excluded_agents: top_agents_downloads)
    end
  end

  def agent_download_rollups
    all_agents = top_agents_downloads.merge({other: other_agents_downloads})

    all_agents.transform_keys { |k| Rollups::DailyAgent.label_for(k) }
  end
end
