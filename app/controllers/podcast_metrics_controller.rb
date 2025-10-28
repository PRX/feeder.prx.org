class PodcastMetricsController < ApplicationController
  include MetricsUtils
  include MetricsQueries

  before_action :set_podcast
  before_action :check_clickhouse, except: %i[show]
  before_action :set_date_range, except: %i[dropdays]
  before_action :set_uniques, only: %i[show uniques]
  before_action :set_dropday_range, only: %i[show dropdays]
  before_action :set_tabs

  def show
  end

  def downloads
    @downloads_within_date_range = downloads_date_range_query(@podcast, @date_start, @date_end, @interval)
    @downloads = single_rollups(@downloads_within_date_range)

    render partial: "metrics/downloads_card", locals: {
      interval: @interval,
      date_range: @date_range,
      downloads: @downloads
    }
  end

  def episodes
    @episodes =
      @podcast.episodes
        .published
        .order(first_rss_published_at: :desc)
        .paginate(params[:episodes], params[:per])

    @episodes_recent =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid), hour: (@date_start..@date_end))
        .select(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
        .group(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
        .load_async
    @episodes_alltime =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid))
        .select(:episode_id, "SUM(count) AS count")
        .group(:episode_id)
        .load_async

    @episode_rollups = multiple_episode_rollups(@episodes, @episodes_recent, @episodes_alltime)

    render partial: "metrics/episodes_card", locals: {
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      episode_rollups: @episode_rollups
    }
  end

  def uniques
    @uniques_rollups =
      Rollups::DailyUnique
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end))
        .select("DATE_TRUNC('#{uniques_interval(@uniques_selection)}', day) AS day, MAX(#{@uniques_selection}) AS #{@uniques_selection}")
        .group("DATE_TRUNC('#{uniques_interval(@uniques_selection)}', day) AS day")
        .order(Arel.sql("DATE_TRUNC('#{uniques_interval(@uniques_selection)}', day) ASC"))
        .load_async

    @uniques = single_rollups(@uniques_rollups)

    render partial: "metrics/uniques_card", locals: {
      uniques_selection: @uniques_selection,
      uniques: @uniques,
      date_range: @date_range
    }
  end

  def dropdays
    @episodes =
      @podcast.episodes
        .published
        .order(first_rss_published_at: :desc)
        .paginate(params[:episode_dropdays], params[:per])

    @dropdays = @episodes.map do |ep|
      if ep[:first_rss_published_at]
        date_start = ep.first_rss_published_at
        date_end = ep.first_rss_published_at + (@dropday_range.to_i - 1).days

        downloads_date_range_query(ep, date_start, date_end, "DAY")
      else
        []
      end
    end.flatten
    @alltime_downloads_by_episode =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, episode_id: @episodes.pluck(:guid))
        .select(:episode_id, "SUM(count) AS count")
        .group(:episode_id)
        .load_async

    @episode_dropdays = multiple_episode_rollups(@episodes, @dropdays, @alltime_downloads_by_episode)

    render partial: "metrics/dropdays_card", locals: {
      episode_dropdays: @episode_dropdays,
      dropday_range: @dropday_range,
      interval: "DAY"
    }
  end

  def geos
    # @top_subdivs =
    #   Rollups::DailyGeo
    #     .where(podcast_id: @podcast.id)
    #     .select(:country_code, :subdiv_code, "DATE_TRUNC('WEEK', day) AS day", "SUM(count) AS count")
    #     .group(:country_code, :subdiv_code, "DATE_TRUNC('WEEK', day) AS day")
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .limit(10)
    # @top_countries =
    #   Rollups::DailyGeo
    #     .where(podcast_id: @podcast.id)
    #     .select(:country_code, "SUM(count) AS count")
    #     .group(:country_code)
    #     .order(Arel.sql("SUM(count) AS count DESC"))
    #     .limit(10)
  end

  def agent_apps
  end

  def agent_types
  end

  def agent_os
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def set_date_range
    @date_preset = metrics_params[:date_preset]
    @date_start = metrics_params[:date_start]
    @date_end = metrics_params[:date_end]
    @interval = metrics_params[:interval]
    @date_range = generate_date_range(@date_start, @date_end, @interval)
  end

  def set_uniques
    @uniques_selection = metrics_params[:uniques_selection]
  end

  def set_dropday_range
    @dropday_range = metrics_params[:dropday_range]
  end

  def set_tabs
    @main_card = metrics_params[:main_card]
    @agents_card = metrics_params[:agents_card]
  end

  def metrics_params
    params
      .permit(:podcast_id, :date_preset, :date_start, :date_end, :interval, :uniques_selection, :dropday_range, :main_card, :agents_card)
      .with_defaults(
        date_preset: "last_30_days",
        date_start: 30.days.ago.utc_date,
        date_end: Date.utc_today,
        interval: "DAY",
        uniques_selection: "last_7_rolling",
        dropday_range: 7,
        main_card: "downloads",
        agents_card: "agent_apps"
      )
  end

  def uniques_interval(selection)
    if selection == "calendar_week"
      "WEEK"
    elsif selection == "calendar_month"
      "MONTH"
    else
      "DAY"
    end
  end
end
