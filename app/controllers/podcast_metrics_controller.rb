class PodcastMetricsController < ApplicationController
  include MetricsUtils

  before_action :set_podcast
  before_action :check_clickhouse, except: %i[show]
  before_action :set_date_range, except: %i[dropdays]
  before_action :set_uniques, only: %i[show uniques]
  before_action :set_dropday_range, only: %i[show dropdays]
  before_action :set_total_agents, only: %i[agent_apps agent_types agent_os]

  def show
  end

  def downloads
    @downloads_within_date_range =
      Rollups::HourlyDownload
        .where(podcast_id: @podcast.id, hour: (@date_start..@date_end))
        .select("DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
        .group("DATE_TRUNC('#{@interval}', hour) AS hour")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
        .load_async

    @downloads = single_rollups(@downloads_within_date_range)

    render partial: "metrics/downloads_card", locals: {
      url: request.fullpath,
      form_id: "podcast_downloads_metrics",
      date_start: @date_start,
      date_end: @date_end,
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
      url: request.fullpath,
      form_id: "podcast_episodes_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      episodes: @episodes,
      episode_rollups: @episode_rollups
    }
  end

  def uniques
    @uniques_rollups =
      Rollups::DailyUnique
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end))
        .select("DATE_TRUNC('#{@interval}', day) AS day, MAX(#{@uniques_selection}) AS #{@uniques_selection}")
        .group("DATE_TRUNC('#{@interval}', day) AS day")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
        .load_async

    @uniques = single_rollups(@uniques_rollups)

    render partial: "metrics/uniques_card", locals: {
      url: request.fullpath,
      form_id: "podcast_uniques_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
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

    @interval = dropdays_params[:interval]
    @fudged_range = if @interval == "DAY"
      # first day is not a "complete" day
      # fudged range matches chart selection
      @dropday_range.to_i - 1
    elsif @interval == "HOUR"
      @dropday_range.to_i
    end
    @dropdays = @episodes.map do |ep|
      if ep[:first_rss_published_at]
        Rollups::HourlyDownload
          .where(episode_id: ep[:guid], hour: (ep.first_rss_published_at..(ep.first_rss_published_at + @fudged_range.send(:"#{@interval.downcase}s"))))
          .select(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour", "SUM(count) AS count")
          .group(:episode_id, "DATE_TRUNC('#{@interval}', hour) AS hour")
          .order(Arel.sql("DATE_TRUNC('#{@interval}', hour) ASC"))
          .load_async
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
      url: request.fullpath,
      form_id: "podcast_dropdays_metrics",
      episode_dropdays: @episode_dropdays,
      dropday_range: @dropday_range,
      interval: @interval
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
    @agent_apps_alltime =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .select("agent_name_id AS code", "SUM(count) AS count")
        .group("agent_name_id AS code")
        .order(Arel.sql("SUM(count) AS count DESC"))
        .limit(10)
        .load_async
    @other_apps_alltime =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .where.not(agent_name_id: @agent_apps_alltime.pluck(:code))
        .select("SUM(count) AS count")
        .load_async
    @agent_apps =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end), agent_name_id: @agent_apps_alltime.pluck(:code))
        .select("DATE_TRUNC('#{@interval}', day) AS day", "agent_name_id AS code", "SUM(count) AS count")
        .group("DATE_TRUNC('#{@interval}', day) AS day", "agent_name_id AS code")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
        .load_async

    render partial: "metrics/agent_card", locals: {
      url: agent_apps_podcast_metrics_path(podcast: @podcast, date_start: @date_start, date_end: @date_end, interval: @interval),
      form_id: "podcast_agents_apps_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      agents: agents_rollups(@agent_apps_alltime, @agent_apps, @other_apps_alltime),
      agents_path: "agent_apps",
      total_alltime: @total_agents,
      totals_in_range: @totals_in_range
    }
  end

  def agent_types
    @agent_types_alltime =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .select("agent_type_id AS code", "SUM(count) AS count")
        .group("agent_type_id AS code")
        .order(Arel.sql("SUM(count) AS count DESC"))
        .limit(10)
        .load_async
    @other_types_alltime =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .where.not(agent_type_id: @agent_types_alltime.pluck(:code))
        .select("SUM(count) AS count")
        .load_async
    @agent_types =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end), agent_type_id: @agent_types_alltime.pluck(:code))
        .select("DATE_TRUNC('#{@interval}', day) AS day", "agent_type_id AS code", "SUM(count) AS count")
        .group("DATE_TRUNC('#{@interval}', day) AS day", "agent_type_id AS code")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
        .load_async

    render partial: "metrics/agent_card", locals: {
      url: agent_types_podcast_metrics_path(podcast: @podcast, date_start: @date_start, date_end: @date_end, interval: @interval),
      form_id: "podcast_agents_types_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      agents: agents_rollups(@agent_types_alltime, @agent_types, @other_types_alltime),
      agents_path: "agent_types",
      total_alltime: @total_agents,
      totals_in_range: @totals_in_range
    }
  end

  def agent_os
    @agent_os_alltime =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .select("agent_os_id AS code", "SUM(count) AS count")
        .group("agent_os_id AS code")
        .order(Arel.sql("SUM(count) AS count DESC"))
        .limit(10)
        .load_async
    @other_os_alltime =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id)
        .where.not(agent_os_id: @agent_os_alltime.pluck(:code))
        .select("SUM(count) AS count")
        .load_async
    @agent_os =
      Rollups::DailyAgent
        .where(podcast_id: @podcast.id, day: (@date_start..@date_end), agent_os_id: @agent_os_alltime.pluck(:code))
        .select("DATE_TRUNC('#{@interval}', day) AS day", "agent_os_id AS code", "SUM(count) AS count")
        .group("DATE_TRUNC('#{@interval}', day) AS day", "agent_os_id AS code")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
        .load_async

    render partial: "metrics/agent_card", locals: {
      url: agent_os_podcast_metrics_path(podcast: @podcast, date_start: @date_start, date_end: @date_end, interval: @interval),
      form_id: "podcast_agents_os_metrics",
      date_start: @date_start,
      date_end: @date_end,
      interval: @interval,
      date_range: @date_range,
      agents: agents_rollups(@agent_os_alltime, @agent_os, @other_os_alltime),
      agents_path: "agent_os",
      total_alltime: @total_agents,
      totals_in_range: @totals_in_range
    }
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
    authorize @podcast, :show?
  end

  def set_date_range
    @date_start = metrics_params[:date_start]
    @date_end = metrics_params[:date_end]
    @interval = metrics_params[:interval]
    @date_range = generate_date_range(@date_start, @date_end, @interval)
  end

  def set_uniques
    @uniques_selection = uniques_params[:uniques_selection]
  end

  def set_dropday_range
    @dropday_range = dropdays_params[:dropday_range]
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
        .select("DATE_TRUNC('#{@interval}', day) AS day", "SUM(count) AS count")
        .group("DATE_TRUNC('#{@interval}', day) AS day")
        .order(Arel.sql("DATE_TRUNC('#{@interval}', day) ASC"))
        .load_async
  end

  def metrics_params
    params
      .permit(:podcast_id, :date_start, :date_end, :interval)
      .with_defaults(
        date_start: 30.days.ago.utc_date,
        date_end: Date.utc_today,
        interval: "DAY"
      )
  end

  def uniques_params
    params
      .permit(:uniques_selection)
      .with_defaults(
        uniques_selection: "last_7_rolling"
      )
      .merge(metrics_params)
  end

  def dropdays_params
    params
      .permit(:dropday_range, :interval)
      .with_defaults(
        dropday_range: 7
      )
      .merge(metrics_params)
  end
end
