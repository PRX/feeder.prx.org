class PodcastMetricsController < ApplicationController
  include MetricsQueries
  include MetricsUtils

  before_action :set_podcast
  before_action :check_clickhouse, except: %i[show]
  before_action :set_date_range, except: %i[dropdays]
  before_action :set_uniques, only: %i[show uniques]
  before_action :set_dropday_range, only: %i[show dropdays]
  before_action :set_total_agents, only: %i[agent_apps agent_types agent_os]
  before_action :set_tabs

  def show
    @url = request.fullpath
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
    @agent_apps_alltime = agent_alltime_query("name", @podcast)
    @agent_apps_in_range = agent_daterange_query("name", @podcast, @date_start, @date_end, @interval, @agent_apps_alltime)

    render partial: "metrics/agent_card", locals: {
      url: request.fullpath,
      form_id: "podcast_agents_apps_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: minimum_interval(@interval),
      date_range: @date_range,
      agents: agents_rollups(@agent_apps_alltime, @agent_apps_in_range),
      agents_path: "agent_apps",
      total_alltime: @total_agents,
      totals_in_range: @totals_in_range
    }
  end

  def agent_types
    @agent_types_alltime = agent_alltime_query("type", @podcast)
    @agent_types_in_range = agent_daterange_query("type", @podcast, @date_start, @date_end, @interval, @agent_types_alltime)

    render partial: "metrics/agent_card", locals: {
      url: request.fullpath,
      form_id: "podcast_agents_types_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: minimum_interval(@interval),
      date_range: @date_range,
      agents: agents_rollups(@agent_types_alltime, @agent_types_in_range),
      agents_path: "agent_types",
      total_alltime: @total_agents,
      totals_in_range: @totals_in_range
    }
  end

  def agent_os
    @agent_os_alltime = agent_alltime_query("os", @podcast)
    @agent_os_in_range = agent_daterange_query("os", @podcast, @date_start, @date_end, @interval, @agent_os_alltime)

    render partial: "metrics/agent_card", locals: {
      url: request.fullpath,
      form_id: "podcast_agents_os_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: minimum_interval(@interval),
      date_range: @date_range,
      agents: agents_rollups(@agent_os_alltime, @agent_os_in_range),
      agents_path: "agent_os",
      total_alltime: @total_agents,
      totals_in_range: @totals_in_range
    }
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  rescue ActiveRecord::RecordNotFound => e
    render_not_found(e)
  end

  def set_date_range
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

  def set_total_agents
    @total_agents =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .select("SUM(count) AS count")
        .load_async
    @totals_in_range =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end))
        .select("DATE_TRUNC('#{minimum_interval(@interval)}', day) AS day", "SUM(count) AS count")
        .group("DATE_TRUNC('#{minimum_interval(@interval)}', day) AS day")
        .order(Arel.sql("DATE_TRUNC('#{minimum_interval(@interval)}', day) ASC"))
        .load_async
  end

  def set_tabs
    @main_card = metrics_params[:main_card]
    @agents_card = metrics_params[:agents_card]
  end

  def metrics_params
    params
      .permit(:podcast_id, :date_start, :date_end, :interval, :main_card, :agents_card, :uniques_selection, :dropday_range)
      .with_defaults(
        date_start: 30.days.ago.utc_date,
        date_end: Date.utc_today,
        interval: "DAY",
        main_card: "downloads",
        agents_card: "agent_apps",
        uniques_selection: "last_7_rolling",
        dropday_range: 7
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
