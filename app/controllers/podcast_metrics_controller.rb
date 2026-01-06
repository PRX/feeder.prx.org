class PodcastMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_podcast
  # before_action :check_clickhouse, except: %i[show]

  def show
  end

  def episode_sparkline
    @episode = Episode.find_by(guid: params[:episode_id])

    render partial: "metrics/episode_sparkline", locals: {
      episode: @episode,
      downloads: @episode.sparkline_downloads
    }
  end

  def episode_trend
    @episode = Episode.find_by(guid: params[:episode_id])
    render partial: "metrics/episode_trend", locals: {
      episode: @episode,
      episode_trend: @episode.episode_trend
    }
  end

  def monthly_downloads
    @date_start = (Date.utc_today - 11.months).beginning_of_month
    @date_end = Date.utc_today
    @date_range = generate_date_range(@date_start, @date_end.beginning_of_month, "MONTH")
    @downloads_within_date_range = daterange_downloads(@podcast, @date_start, @date_end, "MONTH")

    @downloads = single_rollups(@downloads_within_date_range, "Downloads")

    render partial: "metrics/monthly_card", locals: {
      date_range: @date_range,
      downloads: @downloads
    }
  end

  def episodes
    @episodes = @podcast.episodes.published.dropdate_desc.limit(10)
    @date_range = generate_date_range(Date.utc_today - 28.days, Date.utc_today, "DAY")

    @episodes_downloads = daterange_downloads(@episodes)

    @episode_rollups = multiple_episode_rollups(@episodes, @episodes_downloads)

    render partial: "metrics/episodes_card", locals: {
      episode_rollups: @episode_rollups,
      date_range: @date_range
    }
  end

  def feeds
    render partial: "metrics/feeds_card", locals: {
      podcast: @podcast,
      feeds: @podcast.feed_download_rollups
    }
  end

  def seasons
    published_seasons = @podcast.episodes.published.pluck(:season_number).uniq

    @season_rollups = published_seasons.map do |season|
      episodes = @podcast.episodes.published.where(season_number: season)
      rollup = alltime_downloads(episodes, "podcast_id")

      {
        season_number: season,
        downloads: rollup.first
      }
    end

    render partial: "metrics/seasons_card", locals: {
      seasons: @season_rollups
    }
  end

  def countries
    date_start = (Date.utc_today - 28.days).to_s
    date_end = Date.utc_today.to_s

    top_countries =
      Rollups::DailyGeo
        .where(podcast_id: @podcast.id, day: date_start..date_end)
        .select(:country_code, "SUM(count) AS count")
        .group(:country_code)
        .order(Arel.sql("SUM(count) AS count DESC"))
        .final
        .limit(10)
        .load_async

    top_country_codes = top_countries.pluck(:country_code)

    other_countries =
      Rollups::DailyGeo
        .where(podcast_id: @podcast.id, day: date_start..date_end)
        .where.not(country_code: top_country_codes)
        .select("'Other' AS country_code", "SUM(count) AS count")
        .final
        .load_async

    @country_rollups = []
    @country_rollups << top_countries
    @country_rollups << other_countries

    render partial: "metrics/countries_card", locals: {
      countries: @country_rollups.flatten
    }
  end

  def agents
    date_start = (Date.utc_today - 28.days).to_s
    date_end = Date.utc_today.to_s

    agent_apps =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id, day: date_start..date_end)
        .select("agent_name_id AS code", "SUM(count) AS count")
        .group("agent_name_id AS code")
        .order(Arel.sql("SUM(count) AS count DESC"))
        .final
        .limit(10)
        .load_async

    top_apps_ids = agent_apps.pluck(:code)
    other_apps =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id, day: date_start..date_end)
        .where.not(agent_name_id: top_apps_ids)
        .select("'Other' AS code", "SUM(count) AS count")
        .final
        .load_async

    @agent_rollups = []
    @agent_rollups << agent_apps
    @agent_rollups << other_apps

    render partial: "metrics/agent_apps_card", locals: {
      agents: @agent_rollups.flatten
    }
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def metrics_params
    params
      .permit(:podcast_id, :episode_id, :prev_episode_id)
  end

  def publish_hour(episode)
    if episode.first_rss_published_at.present?
      episode.first_rss_published_at.beginning_of_hour
    else
      episode.published_at.beginning_of_hour
    end
  end
end
