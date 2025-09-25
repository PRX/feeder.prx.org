class EpisodeMetricsController < ApplicationController
  include MetricsQueries
  include MetricsUtils

  before_action :set_episode
  before_action :check_clickhouse, except: %i[show]
  before_action :set_date_range
  before_action :set_total_agents, only: %i[agent_apps agent_types agent_os]

  def show
  end

  def downloads
    @downloads_within_date_range = downloads_date_range_query(@episode, @date_start, @date_end, @interval)
    @downloads = single_rollups(@downloads_within_date_range, @episode.title)

    render partial: "metrics/downloads_card", locals: {
      url: request.fullpath,
      form_id: "episode_downloads_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      downloads: @downloads
    }
  end

  def geos
  end

  def agent_apps
    @agent_apps_alltime = agent_alltime_query("name", @episode)
    @agent_apps_in_range = agent_daterange_query("name", @episode, @date_start, @date_end, @interval, @agent_apps_alltime)

    render partial: "metrics/agent_card", locals: {
      url: request.fullpath,
      form_id: "episode_agents_apps_metrics",
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
    @agent_types_alltime = agent_alltime_query("type", @episode)
    @agent_types_in_range = agent_daterange_query("type", @episode, @date_start, @date_end, @interval, @agent_types_alltime)

    render partial: "metrics/agent_card", locals: {
      url: request.fullpath,
      form_id: "episode_agents_types_metrics",
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
    @agent_os_alltime = agent_alltime_query("os", @episode)
    @agent_os_in_range = agent_daterange_query("os", @episode, @date_start, @date_end, @interval, @agent_os_alltime)

    render partial: "metrics/agent_card", locals: {
      url: request.fullpath,
      form_id: "episode_agents_os_metrics",
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

  def set_episode
    @episode = Episode.find_by(guid: params[:episode_id])
    @podcast = @episode.podcast
    authorize @episode, :show?
  end

  def set_date_range
    @date_start = metrics_params[:date_start]
    @date_end = metrics_params[:date_end]
    @interval = metrics_params[:interval]
    @date_range = generate_date_range(@date_start, @date_end, @interval)
  end

  def set_total_agents
    @total_agents =
      Rollups::DailyAgent
        .where(episode_id: @episode.guid)
        .select("SUM(count) AS count")
        .load_async
    @totals_in_range =
      Rollups::DailyAgent
        .where(episode_id: @episode.guid, day: (@date_start..@date_end))
        .select("DATE_TRUNC('#{minimum_interval(@interval)}', day) AS day", "SUM(count) AS count")
        .group("DATE_TRUNC('#{minimum_interval(@interval)}', day) AS day")
        .order(Arel.sql("DATE_TRUNC('#{minimum_interval(@interval)}', day) ASC"))
        .load_async
  end

  def metrics_params
    params
      .permit(:episode_id, :date_start, :date_end, :interval)
      .with_defaults(
        date_start: 28.days.ago.utc_date,
        date_end: Date.utc_today,
        interval: "DAY"
      )
  end
end
